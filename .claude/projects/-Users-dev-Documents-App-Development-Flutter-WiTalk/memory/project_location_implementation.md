---
name: project-location-implementation
description: Location system fully implemented in Flutter — service, providers, permission screen, lifecycle wiring
metadata:
  type: project
---

Location system migrated from RN (locationService.js) to Flutter. Fully connected to server.

**Why:** Migration from React Native to Flutter; needed exact business logic parity.

**How to apply:** All location work should go through `LocationService` singleton (`locationService`). Do not call `Geolocator` directly in screens.

## Files created/modified
- `lib/services/location_service.dart` — core service (cache waterfall, Nominatim geocode, server update, 5-min tracker)
- `lib/providers/location_provider.dart` — `locationPermissionProvider` (granted/hasSeenScreen), `nearbyFilterProvider` (gender/age/distance, persisted)
- `lib/screens/onboarding/location_permission_screen.dart` — full permission screen shown after onboarding
- `lib/main.dart` — startup lifecycle: warmCache → updateCityOnStartup → getCurrentLocationAndUpdate(force) → startTracking
- `lib/api/app_endpoints.dart` — added `nearbyBirthdays`, `locationBounds`, `locationByCity`
- `lib/screens/connect/nearby_people_screen.dart` — uses LocationService cache-first + parallel nearby+birthdays calls
- `lib/screens/connect/for_you_tab.dart` — uses LocationService instead of Geolocator directly
- `lib/navigation/app_router.dart` — `/location-permission` route, redirect logic after onboarding

## Key API calls
- POST `/v1/location/update` — `{uid, latitude, longitude, city, state, country}` header `x-location-source: app-foreground`
- GET `/v1/location/nearby` — `?uid=&latitude=&longitude=&radius=500`
- GET `/v1/location/birthdays` — `?uid=&latitude=&longitude=&state=`
- PUT `/v1/user/:uid/profile` — `{city, state}` on startup
- Nominatim reverse geocode for city/state/country

## Location resolution waterfall (getLocation)
1. App cache (SharedPrefs `cached_location_data`, 30-min TTL) — instant
2. OS last known position — instant
3. Fresh GPS fix (15s normal / 8s quick mode)
4. Stale cache (ignores TTL) as last resort

## Permission flow
`locationPermissionProvider` tracks `granted` + `hasSeenScreen`. Router redirects `/home`→`/location-permission` if `!granted && !hasSeenScreen`. Screen has Allow + Skip buttons.
