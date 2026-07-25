# React Native → Flutter Migration: Known Pitfalls

## 1. API endpoints returning null membership fields

**Problem**
The `/v1/groups/{id}` endpoint does not return membership-related fields (`is_member`, `can_join`, etc.) even when `userId` is passed as a query param. In React Native this was never hit directly — all community lookups went through `/v1/groups/invite/{code}`, which always returns these fields. When Flutter switched to the ID endpoint first, `is_member` came back as `null`, causing `_truthy(null) = false`, so the "Open Community" button never showed — the user saw "Join Community" even though they were already a member.

**Fix**
After fetching via the ID endpoint, check if `is_member == null`. If so, re-fetch via `/v1/groups/invite/{invite_code}` using the invite code from the first response. The invite endpoint always returns the full membership context.

```dart
if (data != null && data['is_member'] == null) {
  final inviteCode = data['invite_code'] as String?;
  final codeToTry = (inviteCode != null && inviteCode.isNotEmpty)
      ? inviteCode
      : widget.communityId;
  final res = await dioClient.get('/v1/groups/invite/$codeToTry', queryParameters: params);
  final inviteData = res.data['data'] as Map<String, dynamic>?;
  if (inviteData != null) data = inviteData;
}
```

**Debug log that caught it**
```dart
debugPrint('[CommunityInfo] is_member = ${data['is_member']} (${data['is_member'].runtimeType})');
debugPrint('[CommunityInfo] _truthy(is_member) = ${_truthy(data['is_member'])}');
```
Log showed `is_member = null (Null)` — confirming the field was absent, not false.

**Pattern to watch for**
When migrating any screen that shows different UI based on membership/ownership/role, always verify the exact endpoint and check that the API actually returns those fields for the authenticated user. Add a debug log for the raw value and its `runtimeType` before trusting any boolean-like field from the API.
