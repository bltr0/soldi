import 'package:flutter_test/flutter_test.dart';
import 'package:sossoldi/services/places/amap_search.dart';
import 'package:sossoldi/services/places/google_places_search.dart';
import 'package:sossoldi/services/places/kakao_search.dart';
import 'package:sossoldi/services/places/naver_search.dart';
import 'package:sossoldi/services/places/place_search.dart';
import 'package:sossoldi/services/places/place_search_provider.dart';
import 'package:sossoldi/services/places/place_search_settings_store.dart';

void main() {
  test('kakao reply', () {
    final hits = parseKakaoReply({
      'documents': [
        {
          'id': '123',
          'place_name': '스타벅스 강남점',
          'road_address_name': '서울 강남구 강남대로 390',
          'address_name': '서울 강남구 역삼동 825',
          'x': '127.0276',
          'y': '37.4979',
        },
      ],
    });
    expect(hits.single.name, '스타벅스 강남점');
    expect(hits.single.address, '서울 강남구 강남대로 390');
    expect(hits.single.latitude, 37.4979);
    expect(hits.single.longitude, 127.0276);
    expect(hits.single.provider, 'kakao');
    expect(hits.single.providerPlaceId, '123');
  });

  test('naver reply strips tags and scales coordinates', () {
    final hits = parseNaverReply({
      'items': [
        {
          'title': '<b>스타벅스</b> 강남&amp;역삼',
          'roadAddress': '서울 강남구 강남대로 390',
          'mapx': '1270276000',
          'mapy': '374979000',
        },
      ],
    });
    expect(hits.single.name, '스타벅스 강남&역삼');
    expect(hits.single.latitude, closeTo(37.4979, 1e-7));
    expect(hits.single.longitude, closeTo(127.0276, 1e-7));
  });

  test('google reply', () {
    final hits = parseGoogleReply({
      'places': [
        {
          'id': 'ChIJ',
          'displayName': {'text': 'Cafe'},
          'formattedAddress': '1 Main St',
          'location': {'latitude': 48.85, 'longitude': 2.35},
        },
      ],
    });
    expect(hits.single.providerPlaceId, 'ChIJ');
    expect(hits.single.latitude, 48.85);
  });

  test('amap reply converts GCJ-02 to WGS84', () {
    final hits = parseAmapReply({
      'status': '1',
      'pois': [
        {
          'id': 'B000A',
          'name': '天安门',
          'location': '116.397477,39.908692',
          'address': '长安街',
          'cityname': '北京市',
          'pname': '北京市',
        },
      ],
    });
    final hit = hits.single;
    expect(hit.address, '长安街, 北京市');
    // GCJ-02 offset in Beijing is roughly 0.006° lng, 0.0014° lat.
    expect(hit.longitude, closeTo(116.3912, 0.0005));
    expect(hit.latitude, closeTo(39.9073, 0.0005));
  });

  test('amap error status throws', () {
    expect(
      () => parseAmapReply({'status': '0', 'info': 'INVALID_USER_KEY'}),
      throwsA(isA<PlaceSearchException>()),
    );
  });

  test('gcj02 leaves points outside China unchanged', () {
    expect(gcj02ToWgs84(48.85, 2.35), (48.85, 2.35));
  });

  test('provider without key falls back to OSM', () {
    const settings = PlaceSearchSettings(selected: PlaceSearchProvider.naver);
    expect(settings.effective, PlaceSearchProvider.osm);
    final withKeys = settings.copyWith(
      keys: {
        PlaceSearchProvider.naver: ['id', 'secret'],
      },
    );
    expect(withKeys.effective, PlaceSearchProvider.naver);
    final roundTrip = PlaceSearchSettings.fromJson(
      withKeys.toJson().cast<String, dynamic>(),
    );
    expect(roundTrip.effective, PlaceSearchProvider.naver);
    expect(roundTrip.keysFor(PlaceSearchProvider.naver), ['id', 'secret']);
  });

  test('explicit provider without key throws', () {
    expect(
      () => searchPlaces(
        'coffee',
        const PlaceSearchSettings(),
        provider: PlaceSearchProvider.kakao,
      ),
      throwsA(isA<PlaceSearchException>()),
    );
  });
}
