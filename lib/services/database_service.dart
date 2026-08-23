import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'auth_service.dart';

/// Supabase-backed operational data gateway.
///
/// The Flutter client never uses a service-role key. Every call is made with
/// the signed-in user's JWT and is therefore constrained by database RLS.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const DataServiceException('Supabase is not configured.');
    }
    return Supabase.instance.client;
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const DataServiceException(
        'Your session has expired. Please sign in again.',
      );
    }
    return id;
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      List<Map<String, dynamic>>.from(value as List);

  // ── Reports ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchReports({
    bool ownOnly = false,
    String? reportType,
  }) async {
    try {
      const columns =
          'id, reporter_id, report_type, description, photo_url, latitude, '
          'longitude, location_text, status, reviewed_by, created_at, updated_at, '
          'profiles!reports_reporter_id_fkey(full_name, email)';
      dynamic request = _client
          .from('reports')
          .select(columns)
          .isFilter('deleted_at', null);
      if (ownOnly) {
        request = request.eq('reporter_id', _userId);
      }
      if (reportType != null) {
        request = request.eq('report_type', reportType);
      }
      final result = await request.order('created_at', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load reports.',
      );
    }
  }

  Future<Map<String, dynamic>> submitReport({
    required String type,
    required String description,
    required String locationText,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
  }) async {
    try {
      if (type == 'breeding_site') {
        return await _submitBreedingSiteReport(
          description: description,
          locationText: locationText,
          latitude: latitude,
          longitude: longitude,
          photoBytes: photoBytes,
        );
      }

      String? photoPath;
      if (photoBytes != null) {
        photoPath = await uploadPrivateImage(
          bucket: 'report-evidence',
          folder: 'reports',
          bytes: photoBytes,
        );
      }

      final dynamic row = await _client
          .from('reports')
          .insert({
            'reporter_id': _userId,
            'report_type': type,
            'description': description,
            'photo_url': photoPath,
            'latitude': latitude,
            'longitude': longitude,
            'location_text': locationText,
            'status': 'pending',
          })
          .select()
          .single();
      return Map<String, dynamic>.from(row as Map);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to submit the report.',
      );
    }
  }

  Future<Map<String, dynamic>> _submitBreedingSiteReport({
    required String description,
    required String locationText,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
  }) async {
    String? photoPath;
    if (photoBytes != null) {
      photoPath = await uploadPrivateImage(
        bucket: 'waste-evidence',
        folder: 'breeding-sites',
        bytes: photoBytes,
      );
    }

    final values = <String, dynamic>{
      'requester_id': _userId,
      'description': 'Mosquito breeding site report\n\n$description',
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'status': 'pending',
    };
    if (photoPath != null) values['photo_url'] = photoPath;

    try {
      final dynamic row = await _client
          .from('waste_requests')
          .insert(values)
          .select()
          .single();
      return Map<String, dynamic>.from(row as Map);
    } on PostgrestException catch (error) {
      final missingPhotoColumn =
          error.code == '42703' ||
          error.code == 'PGRST204' ||
          error.message.contains('photo_url');
      if (!missingPhotoColumn) rethrow;
      values.remove('photo_url');
      final dynamic row = await _client
          .from('waste_requests')
          .insert(values)
          .select()
          .single();
      return Map<String, dynamic>.from(row as Map);
    }
  }

  /// Whether another report of this type already exists near this spot
  /// recently. Backed by a SECURITY DEFINER Postgres function that returns
  /// only a boolean — never another resident's report details — so this is
  /// safe to call as a resident without punching a hole in report privacy
  /// (see nearby_report_exists in supabase/BantayDengue_FINAL.sql).
  /// Best-effort: a failed/unmigrated check never blocks report submission.
  Future<bool> nearbyReportExists({
    required String reportType,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await _client.rpc(
        'nearby_report_exists',
        params: {
          'p_report_type': reportType,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Count of the signed-in user's own reports of [reportType] filed within
  /// [window] of now. Used to cap how many case reports a resident can file
  /// in a rolling day — the anti-spam control that stands in for the photo
  /// requirement on dengue-case reports (symptoms often aren't
  /// photographable, so that report type can't lean on "a photo costs more
  /// than typing text" the way breeding-site reports do). Best-effort: a
  /// failed lookup never blocks submission, it just skips the cap.
  Future<int> recentOwnReportCount({
    required String reportType,
    required Duration window,
  }) async {
    try {
      final rows = await fetchReports(ownOnly: true, reportType: reportType);
      final cutoff = DateTime.now().toUtc().subtract(window);
      return rows.where((row) {
        final createdAt = DateTime.tryParse('${row['created_at']}');
        return createdAt != null && createdAt.isAfter(cutoff);
      }).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    try {
      await _client
          .from('reports')
          .update({
            'status': status,
            'reviewed_by': _userId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reportId);
      // The integration migration records workflow history, notification, and
      // audit activity atomically in the database after this update succeeds.
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the report.',
      );
    }
  }

  /// Lets a resident edit the content of a report they filed themselves,
  /// while it is still 'pending' (RLS enforces the same rule server-side —
  /// see supabase/APPLY_THIS_NOW.sql — so this cannot be bypassed by
  /// calling the API directly once staff has started reviewing).
  Future<void> updateReport({
    required String reportId,
    required String description,
    required String locationText,
    double? latitude,
    double? longitude,
    Uint8List? newPhotoBytes,
  }) async {
    try {
      String? photoPath;
      if (newPhotoBytes != null) {
        photoPath = await uploadPrivateImage(
          bucket: 'report-evidence',
          folder: 'reports',
          bytes: newPhotoBytes,
        );
      }
      final values = <String, dynamic>{
        'description': description,
        'location_text': locationText,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (photoPath != null) values['photo_url'] = photoPath;

      await _client
          .from('reports')
          .update(values)
          .eq('id', reportId)
          .eq('reporter_id', _userId);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback:
            'Unable to update the report. Only pending reports you '
            'filed yourself can be edited.',
      );
    }
  }

  /// Withdraws a report the resident filed themself, while it is still
  /// 'pending'. This is a SOFT delete: the row stays in the database with
  /// `deleted_at` set, it just stops showing up anywhere in the app
  /// (fetchReports filters it out). Nothing is ever permanently erased —
  /// standard practice so a mistaken or malicious deletion is always
  /// recoverable, and so verification/audit history stays intact. The app
  /// never issues a real SQL DELETE against this table; RLS backs that up
  /// by not granting a delete policy at all (see
  /// supabase/APPLY_THIS_NOW.sql), so even a compromised client
  /// couldn't hard-delete a row.
  Future<void> deleteReport(String reportId) async {
    try {
      await _client
          .from('reports')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', reportId)
          .eq('reporter_id', _userId)
          .eq('status', 'pending');
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback:
            'Unable to delete the report. Only pending reports you '
            'filed yourself can be deleted.',
      );
    }
  }

  // ── Appointments ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAppointments({
    bool ownOnly = false,
  }) async {
    try {
      const columns =
          'id, patient_id, assigned_doctor, scheduled_at, reason, status, '
          'created_at, updated_at, '
          'profiles!appointments_patient_id_fkey(full_name, email, phone)';
      final dynamic result;
      if (ownOnly) {
        result = await _client
            .from('appointments')
            .select(columns)
            .eq('patient_id', _userId)
            .order('scheduled_at');
      } else {
        result = await _client
            .from('appointments')
            .select(columns)
            .order('scheduled_at');
      }
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load appointments.',
      );
    }
  }

  Future<void> createAppointment({
    required DateTime scheduledAt,
    required String reason,
  }) async {
    try {
      await _client.from('appointments').insert({
        'patient_id': _userId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'reason': reason,
        'status': 'pending',
      });
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to book the appointment.',
      );
    }
  }

  /// Resident-facing edit of their own pending appointment — separate from
  /// [updateAppointmentStatus], which is the staff-driven approve/reject/
  /// complete transition. RLS (appointments_update_own_or_staff) already
  /// lets a patient update their own row; the app layer restricts this to
  /// while status is still 'pending' (see appointments_screen.dart) so an
  /// edit can't quietly reschedule a slot staff already approved.
  Future<void> updateAppointmentDetails({
    required String id,
    required DateTime scheduledAt,
    required String reason,
  }) async {
    try {
      await _client
          .from('appointments')
          .update({
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
            'reason': reason,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the appointment.',
      );
    }
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    try {
      final values = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (status == 'approved') values['assigned_doctor'] = _userId;
      await _client.from('appointments').update(values).eq('id', id);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the appointment.',
      );
    }
  }

  // ── Waste operations ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWasteRequests({
    bool ownOnly = false,
  }) async {
    const baseColumns =
        'id, requester_id, description, latitude, longitude, location_text, '
        'status, scheduled_at, created_at, updated_at, '
        'profiles!waste_requests_requester_id_fkey(full_name, phone)';
    const integratedColumns =
        'id, requester_id, description, latitude, longitude, location_text, '
        'photo_url, handled_by, completion_photo_url, status, scheduled_at, '
        'created_at, updated_at, '
        'profiles!waste_requests_requester_id_fkey(full_name, phone)';

    Future<dynamic> query(String columns) {
      var request = _client.from('waste_requests').select(columns);
      if (ownOnly) request = request.eq('requester_id', _userId);
      return request.order('created_at', ascending: false);
    }

    try {
      try {
        return _rows(await query(integratedColumns));
      } on PostgrestException catch (error) {
        // Keep the existing hosted schema usable until the additive migration
        // introduces the three optional waste-evidence/assignment columns.
        final missingIntegrationColumn =
            error.code == '42703' ||
            error.code == 'PGRST204' ||
            error.message.contains('photo_url') ||
            error.message.contains('handled_by') ||
            error.message.contains('completion_photo_url');
        if (!missingIntegrationColumn) rethrow;
        return _rows(await query(baseColumns));
      }
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load waste requests.',
      );
    }
  }

  Future<void> createWasteRequest({
    required String description,
    required String locationText,
    required DateTime preferredDate,
    double? latitude,
    double? longitude,
    Uint8List? photoBytes,
  }) async {
    try {
      String? photoPath;
      if (photoBytes != null) {
        photoPath = await uploadPrivateImage(
          bucket: 'waste-evidence',
          folder: 'waste',
          bytes: photoBytes,
        );
      }
      final values = <String, dynamic>{
        'requester_id': _userId,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'location_text': locationText,
        'scheduled_at': preferredDate.toUtc().toIso8601String(),
        'status': 'pending',
      };
      // The additive migration introduces this column. Requests without a
      // photo remain compatible with the original hosted schema.
      if (photoPath != null) values['photo_url'] = photoPath;
      await _client.from('waste_requests').insert(values);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to submit the waste request.',
      );
    }
  }

  Future<void> updateWasteStatus(String id, String status) async {
    final values = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'scheduled' || status == 'collected') 'handled_by': _userId,
    };
    try {
      try {
        await _client.from('waste_requests').update(values).eq('id', id);
      } on PostgrestException catch (error) {
        // Admin/health-worker waste tools stay compatible with the base
        // schema. The dedicated personnel role itself still requires the
        // supplied migration and its RLS policies.
        final missingAssignmentColumn =
            error.code == '42703' ||
            error.code == 'PGRST204' ||
            error.message.contains('handled_by');
        if (!missingAssignmentColumn) rethrow;
        values.remove('handled_by');
        await _client.from('waste_requests').update(values).eq('id', id);
      }
      // Workflow side effects are authoritative database triggers after the
      // additive migration is deployed.
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the waste request.',
      );
    }
  }

  // ── Hotspots, advisories and notifications ──────────────────────────────

  Future<List<Map<String, dynamic>>> fetchHotspots() async {
    try {
      final result = await _client
          .from('hotspots')
          .select()
          .order('case_count', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load hotspot data.',
      );
    }
  }

  Future<void> upsertHotspot({
    String? id,
    required String barangay,
    required String riskLevel,
    required int caseCount,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final values = <String, dynamic>{
        'name': barangay,
        'barangay': barangay,
        'risk_level': riskLevel,
        'case_count': caseCount,
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (id == null) {
        await _client.from('hotspots').insert(values);
      } else {
        await _client.from('hotspots').update(values).eq('id', id);
      }
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to save the hotspot.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdvisories() async {
    try {
      final result = await _client
          .from('health_advisories')
          .select()
          .order('created_at', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load advisories.',
      );
    }
  }

  Future<void> publishAdvisory({
    required String title,
    required String body,
  }) async {
    try {
      await _client.from('health_advisories').insert({
        'author_id': _userId,
        'title': title,
        'body': body,
      });
      await logActivity('advisory_published', {'title': title});
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to publish the advisory.',
      );
    }
  }

  // ── Announcements ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    try {
      final result = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load announcements.',
      );
    }
  }

  Future<void> publishAnnouncement({
    required String title,
    required String body,
  }) async {
    try {
      await _client.from('announcements').insert({
        'author_id': _userId,
        'title': title,
        'body': body,
      });
      await logActivity('announcement_published', {'title': title});
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to publish the announcement.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    try {
      final result = await _client
          .from('notifications')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load notifications.',
      );
    }
  }

  /// Unread count only, for the bell badge every page shows — cheap enough
  /// (per-user row count, not the full table) to call every time the badge
  /// needs a number instead of a guess.
  Future<int> fetchUnreadNotificationCount() async {
    try {
      final result = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', _userId)
          .eq('read', false);
      return _rows(result).length;
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load notifications.',
      );
    }
  }

  /// Live updates for the signed-in user's own notifications — the bell
  /// badge refreshes its count as soon as something new arrives, instead of
  /// only updating the next time the shell happens to rebuild.
  RealtimeChannel watchNotifications(void Function() onChange) {
    return _client
        .channel('notifications-$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await _client.from('notifications').update({'read': true}).eq('id', id);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the notification.',
      );
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', _userId)
          .eq('read', false);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update notifications.',
      );
    }
  }

  /// Fires the `outbreak_alert` notification type — schema, icon, and
  /// routing already existed in notifications_panel.dart, nothing ever
  /// inserted one until this. `notifications.user_id` is NOT NULL (one row
  /// per recipient, no broadcast column exists yet — see
  /// health_advisories' own lack of barangay targeting), so this only
  /// reaches the specific residents in [residentIds] rather than every
  /// resident in the system. The caller is expected to pass the reporters
  /// whose verified reports are physically near the hotspot, which is the
  /// only "who's near this outbreak" signal available without the
  /// geographic-targeting schema work planned separately.
  Future<void> sendOutbreakAlerts({
    required Iterable<String> residentIds,
    required String barangay,
    required String riskLevel,
  }) async {
    final ids = residentIds.toSet();
    if (ids.isEmpty) return;
    try {
      await _client.from('notifications').insert(
        ids
            .map(
              (id) => {
                'user_id': id,
                'title': 'Dengue hotspot alert',
                'body':
                    '$barangay has been flagged as a $riskLevel-risk '
                    'dengue area based on verified case reports near you. '
                    'Take precautions and watch for symptoms.',
                'type': 'outbreak_alert',
                'read': false,
              },
            )
            .toList(),
      );
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to send outbreak alerts.',
      );
    }
  }

  // ── Community stories (resident peer-support feed) ──────────────────────
  // See supabase/COMMUNITY_STORIES.sql for the schema/RLS this relies on.
  // Resident-only (RLS enforces this server-side too — these calls simply
  // fail with a permission error for any other role, same as every other
  // RLS-gated write in this file).

  /// Looks up name/photo for a set of author ids via the narrow
  /// `community_author_info` SECURITY DEFINER function (see
  /// supabase/COMMUNITY_AUTHOR_LOOKUP.sql) and stitches a `profiles` map
  /// onto each row, matching the shape a Postgrest embed would have
  /// produced. NOT a real embed: `profiles`' own RLS only lets a resident
  /// read their own row (staff can read everyone's, a resident can't read
  /// another resident's) — an embedded `profiles!...` join here would
  /// silently return null for every other resident's post. This function
  /// exists specifically so that doesn't happen.
  Future<List<Map<String, dynamic>>> _attachAuthors(
    List<Map<String, dynamic>> rows,
    String authorIdKey,
  ) async {
    final ids = rows
        .map((r) => r[authorIdKey] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return rows;
    final authorRows = _rows(
      await _client.rpc('community_author_info', params: {'p_ids': ids}),
    );
    final byId = {for (final a in authorRows) '${a['id']}': a};
    for (final row in rows) {
      final author = byId['${row[authorIdKey]}'];
      row['profiles'] = author == null
          ? null
          : {'full_name': author['full_name'], 'photo_url': author['photo_url']};
    }
    return rows;
  }

  /// Paginated, newest-first. [before]/[after] are `created_at` cursors —
  /// [before] powers "load more" (infinite scroll, going further back),
  /// [after] powers the realtime feed's "what's new since I last looked"
  /// check. Never fetches the whole table at once: with the feed
  /// potentially serving every resident in the barangay at once, an
  /// unbounded `select()` is exactly the kind of thing that stops scaling
  /// quietly (see BATCH_PROCESSING conventions used elsewhere in this app).
  Future<List<Map<String, dynamic>>> fetchCommunityPosts({
    int limit = 12,
    String? before,
    String? after,
  }) async {
    try {
      var request = _client.from('community_posts').select();
      if (before != null) request = request.lt('created_at', before);
      if (after != null) request = request.gt('created_at', after);
      final result = await request
          .order('created_at', ascending: false)
          .limit(limit);
      return await _attachAuthors(_rows(result), 'author_id');
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load community stories.',
      );
    }
  }

  /// Which of the given post ids are still visible (not soft-deleted, and
  /// RLS-readable by the caller) — used by the realtime feed to notice a
  /// post it already has on screen got removed/moderated elsewhere, without
  /// re-fetching full post rows just to find that out.
  Future<Set<String>> fetchVisibleCommunityPostIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final result = await _client
          .from('community_posts')
          .select('id')
          .inFilter('id', ids)
          .isFilter('deleted_at', null);
      return _rows(result).map((r) => '${r['id']}').toSet();
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to refresh community stories.',
      );
    }
  }

  /// Live updates for the Community feed — a new post, comment, or "love"
  /// from any resident. The screen uses this to refresh in place (like a
  /// social app's live feed) instead of leaving residents to pull-to-refresh
  /// to see new activity. The pull-to-refresh/refresh-button path still
  /// works independently — this is additive, not a replacement.
  /// Caller owns the returned channel and must call `.unsubscribe()` on it
  /// (e.g. in `dispose()`).
  RealtimeChannel watchCommunityFeed(void Function() onChange) {
    return _client
        .channel('community-feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_posts',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_comments',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'community_reactions',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  /// All reactions for the given posts in one call — the feed screen
  /// computes per-post counts and "did I react" client-side from this,
  /// the same groupBy-on-already-fetched-data pattern used throughout this
  /// app rather than a server-side aggregate query.
  Future<List<Map<String, dynamic>>> fetchCommunityReactions(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return [];
    try {
      final result = await _client
          .from('community_reactions')
          .select()
          .inFilter('post_id', postIds);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load reactions.',
      );
    }
  }

  /// Comment *counts* only (id + post_id, no content) for the feed list —
  /// full comment content is fetched separately, only when a resident
  /// actually opens a post's comment thread.
  Future<List<Map<String, dynamic>>> fetchCommunityCommentCounts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return [];
    try {
      final result = await _client
          .from('community_comments')
          .select('id, post_id')
          .inFilter('post_id', postIds)
          .isFilter('deleted_at', null);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load comment counts.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchCommunityComments(
    String postId,
  ) async {
    try {
      final result = await _client
          .from('community_comments')
          .select()
          .eq('post_id', postId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);
      return await _attachAuthors(_rows(result), 'author_id');
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load comments.',
      );
    }
  }

  Future<void> createCommunityPost({
    required String content,
    Uint8List? photoBytes,
  }) async {
    try {
      String? photoPath;
      if (photoBytes != null) {
        photoPath = await uploadPrivateImage(
          bucket: 'community-photos',
          folder: 'posts',
          bytes: photoBytes,
        );
      }
      await _client.from('community_posts').insert({
        'author_id': _userId,
        'content': content,
        if (photoPath != null) 'photo_url': photoPath,
      });
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to share your story.',
      );
    }
  }

  /// Soft delete — matches every other table in this schema. Author-owned
  /// (RLS `community_posts_update_own`) or admin moderation
  /// (`community_posts_moderate`) both route through this same call; RLS
  /// decides which one actually applies to the signed-in account.
  Future<void> deleteCommunityPost(String id) async {
    try {
      await _client
          .from('community_posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to remove this post.',
      );
    }
  }

  Future<void> createCommunityComment({
    required String postId,
    required String content,
  }) async {
    try {
      await _client.from('community_comments').insert({
        'post_id': postId,
        'author_id': _userId,
        'content': content,
      });
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to post your comment.',
      );
    }
  }

  Future<void> deleteCommunityComment(String id) async {
    try {
      await _client
          .from('community_comments')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to remove this comment.',
      );
    }
  }

  /// Reactions have no soft-delete state (see COMMUNITY_STORIES.sql) — a
  /// real insert/delete toggle, same as un-liking a post anywhere else.
  Future<void> setCommunityReaction({
    required String postId,
    required bool reacted,
  }) async {
    try {
      if (reacted) {
        await _client.from('community_reactions').insert({
          'post_id': postId,
          'user_id': _userId,
        });
      } else {
        await _client
            .from('community_reactions')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', _userId);
      }
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update your reaction.',
      );
    }
  }

  String communityPhotoPublicUrl(String path) =>
      _client.storage.from('community-photos').getPublicUrl(path);

  // ── Profiles and administration ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    try {
      final result = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(error, fallback: 'Unable to load users.');
    }
  }

  Future<void> updateOwnProfile({
    required String fullName,
    String? phone,
    String? barangay,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            'phone': phone,
            'barangay': barangay,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _userId);
      await authService.refreshProfile();
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update your profile.',
      );
    }
  }

  /// Uploads [bytes] to the public `avatars` bucket (see
  /// supabase/AVATAR_STORAGE.sql) and saves the resulting path as the
  /// caller's profile photo.
  Future<void> updateProfilePhoto(Uint8List bytes) async {
    final path = await uploadPrivateImage(
      bucket: 'avatars',
      folder: 'avatar',
      bytes: bytes,
    );
    try {
      await _client
          .from('profiles')
          .update({
            'photo_url': path,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _userId);
      await authService.refreshProfile();
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to save your profile photo.',
      );
    }
  }

  /// The `avatars` bucket is public, so its URL is a stable direct link —
  /// no signing/expiry to manage, unlike the private evidence buckets.
  String avatarPublicUrl(String path) =>
      _client.storage.from('avatars').getPublicUrl(path);

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _client.from('profiles').update({'role': role}).eq('id', userId);
      await logActivity('user_role_changed', {'user_id': userId, 'role': role});
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to update the user role.',
      );
    }
  }

  Future<void> setUserActive(String userId, bool active) async {
    try {
      await _client
          .from('profiles')
          .update({'is_active': active})
          .eq('id', userId);
      await logActivity('user_access_changed', {
        'user_id': userId,
        'active': active,
      });
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback:
            'Unable to update account access. Apply the integration migration first.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchSystemActivity() async {
    try {
      final result = await _client
          .from('system_activity')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      return _rows(result);
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback: 'Unable to load system activity.',
      );
    }
  }

  Future<void> logActivity(String action, Map<String, dynamic> details) async {
    try {
      await _client.from('system_activity').insert({
        'actor_id': _userId,
        'action': action,
        'details': details,
      });
    } catch (error) {
      // Audit insertion is best-effort from the client. Authoritative workflow
      // audit triggers are also supplied in the integration migration. Still
      // surface the failure in debug console so a broken audit trail isn't
      // silently invisible during development.
      debugPrint('logActivity($action) failed: $error');
    }
  }

  Future<String?> createEvidenceUrl({
    required String bucket,
    required String? path,
  }) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 300);
    } catch (error) {
      debugPrint('createEvidenceUrl($bucket, $path) failed: $error');
      return null;
    }
  }

  Future<String> uploadPrivateImage({
    required String bucket,
    required String folder,
    required Uint8List bytes,
  }) async {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final path = '$_userId/$folder/$timestamp.jpg';
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      return path;
    } catch (error) {
      throw DataServiceException.from(
        error,
        fallback:
            'The private evidence bucket is not ready. Apply the Supabase integration migration and try again.',
      );
    }
  }
}

class DataServiceException implements Exception {
  final String message;
  const DataServiceException(this.message);

  factory DataServiceException.from(Object error, {required String fallback}) {
    if (error is DataServiceException) return error;
    if (error is AuthException && error.message.isNotEmpty) {
      return DataServiceException(error.message);
    }
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      // Custom exceptions we raise ourselves in Postgres triggers (e.g. the
      // report rate limit) use this Postgres code and are already written
      // to be shown to the person directly — don't replace them with the
      // generic fallback.
      if (error.code == 'P0001') {
        return DataServiceException(error.message);
      }
      if (message.contains('row-level security') ||
          message.contains('permission')) {
        return const DataServiceException(
          'You do not have permission to perform this action.',
        );
      }
      if (message.contains('does not exist') ||
          message.contains('schema cache')) {
        return DataServiceException(
          '$fallback Apply the latest Supabase migration.',
        );
      }
    }
    return DataServiceException(fallback);
  }

  @override
  String toString() => message;
}
