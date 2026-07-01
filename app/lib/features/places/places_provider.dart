import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/supabase_client.dart';
import 'planb_place.dart';
import 'restaurant.dart';

part 'places_provider.g.dart';

/// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.
@riverpod
Future<List<Restaurant>> restaurants(Ref ref, String stadiumId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('restaurants')
      .select('id, name, pick_type, category, description, source_url')
      .eq('stadium_id', stadiumId)
      .order('pick_type');
  return rows.map(Restaurant.fromJson).toList();
}

/// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).
@riverpod
Future<List<PlanbPlace>> planbPlaces(Ref ref, String stadiumId) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('planb_places')
      .select('id, name, category, description, source_url')
      .eq('stadium_id', stadiumId)
      .order('name');
  return rows.map(PlanbPlace.fromJson).toList();
}
