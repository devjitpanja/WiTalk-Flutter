import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../api/dio_client.dart';

class NearbyPeopleScreen extends ConsumerStatefulWidget {
  const NearbyPeopleScreen({super.key});
  @override
  ConsumerState<NearbyPeopleScreen> createState() => _NearbyPeopleScreenState();
}

class _NearbyPeopleScreenState extends ConsumerState<NearbyPeopleScreen> {
  Position? _position;
  List<dynamic> _users = [];
  bool _loading = true;
  final _mapCtrl = MapController();

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _loading = false); return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final res = await dioClient.get('/v1/nearby?lat=${pos.latitude}&lng=${pos.longitude}&radius=10');
      setState(() { _position = pos; _users = res.data['data'] ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Nearby People', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryButton))
        : _position == null
            ? const Center(child: Text('Location permission required', style: TextStyle(color: Colors.white70, fontFamily: 'Outfit')))
            : Column(children: [
                SizedBox(height: 300, child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(initialCenter: LatLng(_position!.latitude, _position!.longitude), initialZoom: 13),
                  children: [
                    TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', subdomains: const ['a','b','c','d']),
                    MarkerLayer(markers: [
                      Marker(point: LatLng(_position!.latitude, _position!.longitude), child: const Icon(Icons.my_location, color: AppColors.primaryButton, size: 28)),
                      ..._users.map((u) {
                        final lat = (u['lat'] as num?)?.toDouble() ?? 0;
                        final lng = (u['lng'] as num?)?.toDouble() ?? 0;
                        final userId = u['id'] as String? ?? '';
                        final pic = u['profile_pic'] as String?;
                        return Marker(
                          point: LatLng(lat, lng),
                          child: GestureDetector(
                            onTap: () => context.push('/user/$userId'),
                            child: CircleAvatar(
                              radius: 18, backgroundColor: AppColors.primaryButton,
                              backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                              child: pic == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                            ),
                          ),
                        );
                      }),
                    ]),
                  ],
                )),
                Expanded(child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i] as Map<String, dynamic>;
                    final name = u['name'] as String? ?? '';
                    final pic = u['profile_pic'] as String?;
                    final userId = u['id'] as String? ?? '';
                    final dist = u['distance_km']?.toString() ?? '?';
                    return ListTile(
                      leading: CircleAvatar(radius: 22, backgroundColor: AppColors.border,
                        backgroundImage: pic != null ? CachedNetworkImageProvider(pic) : null,
                        child: pic == null ? const Icon(Icons.person, color: Colors.white) : null),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                      subtitle: Text('$dist km away', style: const TextStyle(color: AppColors.textTertiary, fontFamily: 'Outfit', fontSize: 12)),
                      onTap: () => context.push('/user/$userId'),
                    );
                  },
                )),
              ]),
  );
}
