#!/usr/bin/env python3
"""Offline structure check; Flutter analyze remains the source of truth."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
required = [
    'pubspec.yaml', 'lib/main.dart', 'lib/app.dart', 'lib/router/app_router.dart',
    'lib/screens/dashboard/dashboard_screen.dart', 'lib/screens/map/hotspot_map_screen.dart',
    'lib/screens/reports/reports_screen.dart', 'lib/screens/appointments/appointments_screen.dart',
    'lib/screens/waste/waste_requests_screen.dart', 'lib/screens/advisories/advisories_screen.dart',
    'lib/screens/assistant/assistant_screen.dart', 'lib/screens/users/users_screen.dart',
    'lib/screens/analytics/analytics_screen.dart',
    'supabase/migrations/202608110001_initial_schema.sql',
]
errors = []
for item in required:
    if not (root / item).is_file():
        errors.append(f'Missing required file: {item}')

for source in (root / 'lib').rglob('*.dart'):
    text = source.read_text(encoding='utf-8')
    for relative in re.findall(r"import\s+'([^']+)';", text):
        if relative.startswith(('dart:', 'package:')):
            continue
        if not (source.parent / relative).resolve().is_file():
            errors.append(f'{source.relative_to(root)} imports missing file {relative}')

if errors:
    print('\n'.join(f'ERROR: {item}' for item in errors))
    sys.exit(1)
print(f'OK: required structure and relative imports found under {root}')
print('Next: flutter pub get && flutter analyze && flutter test')
