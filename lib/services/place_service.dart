import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/maps_config.dart';

/// Model class for place suggestion
class PlaceSuggestion {
  /// The place ID
  final String placeId;

  /// The description/address of the place
  final String description;

  /// Constructor
  PlaceSuggestion({
    required this.placeId,
    required this.description,
  });

  /// Factory to create from JSON
  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'],
      description: json['description'],
    );
  }
}

/// Model class for place details
class Place {
  /// The place ID
  final String placeId;

  /// The formatted address
  final String formattedAddress;

  /// The place name
  final String name;

  /// The geographic location of the place
  final LatLng location;

  /// Constructor
  Place({
    required this.placeId,
    required this.formattedAddress,
    required this.name,
    required this.location,
  });

  /// Factory to create from place details JSON
  factory Place.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final geometry = result['geometry'];
    final location = geometry['location'];

    return Place(
      placeId: result['place_id'],
      formattedAddress: result['formatted_address'],
      name: result['name'],
      location: LatLng(
        location['lat'],
        location['lng'],
      ),
    );
  }
}

/// Service for handling Google Places API requests
class PlaceService {
  final String _apiKey;
  final bool _useMockData;
  final http.Client _client;

  PlaceService({
    String? apiKey,
    bool? useMockData,
    http.Client? client,
  })  : _apiKey = apiKey ?? MapsConfig.apiKey,
        _client = client ?? http.Client(),
        _useMockData = useMockData ?? (apiKey ?? MapsConfig.apiKey).isEmpty;

  /// Get place suggestions based on input
  Future<List<PlaceSuggestion>> getPlaceSuggestions(String input) async {
    print('Getting suggestions for: "$input"');
    if (_useMockData) {
      final suggestions = _getMockSuggestions(input);
      print('Found ${suggestions.length} mock suggestions');
      return suggestions;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': input, 'key': _apiKey},
    );

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == 'OK') {
        return result['predictions']
            .map<PlaceSuggestion>((p) => PlaceSuggestion.fromJson(p))
            .toList();
      }
      if (result['status'] == 'ZERO_RESULTS') {
        return [];
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestions');
    }
  }

  /// Get place details from place ID
  Future<Place> getPlaceDetails(String placeId) async {
    print('Getting place details for ID: $placeId');
    if (_useMockData) {
      final place = _getMockPlaceDetail(placeId);
      print(
          'Found mock place: ${place.name} at ${place.location.latitude}, ${place.location.longitude}');
      return place;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {'place_id': placeId, 'key': _apiKey},
    );

    final response = await _client.get(url);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == 'OK') {
        return Place.fromJson(result);
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch place details');
    }
  }

  /// Mock suggestions for development/testing
  List<PlaceSuggestion> _getMockSuggestions(String input) {
    // Return empty list for empty input
    if (input.isEmpty) {
      print('Empty input, returning no suggestions');
      return [];
    }

    // Convert input to lowercase for case-insensitive matching
    final query = input.toLowerCase().trim();
    print('Looking for mock places containing: "$query"');

    // List of mock places
    final mockPlaces = [
      {'place_id': 'mock_sf', 'description': 'San Francisco, CA, USA'},
      {'place_id': 'mock_lincoln_hs', 'description': 'Lincoln High School, San Francisco, CA, USA'},
      {'place_id': 'mock_sfo_airport', 'description': 'San Francisco International Airport (SFO), CA, USA'},
      {'place_id': 'mock_nyc', 'description': 'New York, NY, USA'},
      {'place_id': 'mock_chicago', 'description': 'Chicago, IL, USA'},
      {'place_id': 'mock_la', 'description': 'Los Angeles, CA, USA'},
      {'place_id': 'mock_seattle', 'description': 'Seattle, WA, USA'},
      {'place_id': 'mock_boston', 'description': 'Boston, MA, USA'},
      {'place_id': 'mock_miami', 'description': 'Miami, FL, USA'},
      {'place_id': 'mock_denver', 'description': 'Denver, CO, USA'},
      {'place_id': 'mock_austin', 'description': 'Austin, TX, USA'},
      {'place_id': 'mock_san_diego', 'description': 'San Diego, CA, USA'},
      {'place_id': 'mock_portland', 'description': 'Portland, OR, USA'},
      {'place_id': 'mock_atlanta', 'description': 'Atlanta, GA, USA'},
      {'place_id': 'mock_dallas', 'description': 'Dallas, TX, USA'},
      {'place_id': 'mock_houston', 'description': 'Houston, TX, USA'},
      {'place_id': 'mock_philly', 'description': 'Philadelphia, PA, USA'},
      // Add some additional easy to match examples
      {'place_id': 'mock_london', 'description': 'London, UK'},
      {'place_id': 'mock_paris', 'description': 'Paris, France'},
      {'place_id': 'mock_tokyo', 'description': 'Tokyo, Japan'},
      {'place_id': 'mock_rome', 'description': 'Rome, Italy'},
      {'place_id': 'mock_berlin', 'description': 'Berlin, Germany'},
      // Add more cities with just the first letter for easier matching
      {'place_id': 'mock_vegas', 'description': 'Las Vegas, NV, USA'},
      {'place_id': 'mock_orlando', 'description': 'Orlando, FL, USA'},
      {'place_id': 'mock_dc', 'description': 'Washington DC, USA'},
      {'place_id': 'mock_sydney', 'description': 'Sydney, Australia'},
      {'place_id': 'mock_madrid', 'description': 'Madrid, Spain'},
      {'place_id': 'mock_toronto', 'description': 'Toronto, Canada'},
      {'place_id': 'mock_cancun', 'description': 'Cancun, Mexico'},
      {'place_id': 'mock_cairo', 'description': 'Cairo, Egypt'},
      {'place_id': 'mock_vancouver', 'description': 'Vancouver, Canada'},
      {'place_id': 'mock_moscow', 'description': 'Moscow, Russia'},
    ];

    // For very short queries (1-2 chars), use prefix matching instead of contains
    List<Map<String, String>> filteredPlaces;
    if (query.length <= 2) {
      print('Short query, using prefix matching');
      filteredPlaces = mockPlaces
          .where((place) => place['description']!
              .toLowerCase()
              .split(',')[0]
              .trim()
              .startsWith(query))
          .toList();

      // If prefix matching yields no results, fall back to contains
      if (filteredPlaces.isEmpty) {
        print('No prefix matches, falling back to contains');
        filteredPlaces = mockPlaces
            .where(
                (place) => place['description']!.toLowerCase().contains(query))
            .toList();
      }
    } else {
      // Regular contains matching for longer queries
      filteredPlaces = mockPlaces
          .where((place) => place['description']!.toLowerCase().contains(query))
          .toList();
    }

    print('Found ${filteredPlaces.length} matching places for "$query"');
    // Print the matching places for debugging
    for (var place in filteredPlaces.take(5)) {
      print('  - ${place['description']}');
    }

    // Limit to 5 results
    final limitedResults = filteredPlaces.take(5).toList();

    // Convert to PlaceSuggestion objects
    return limitedResults
        .map((place) => PlaceSuggestion.fromJson(place))
        .toList();
  }

  /// Mock place details for development/testing
  Place _getMockPlaceDetail(String placeId) {
    // Map of mock place details keyed by place_id
    final mockPlaceDetails = {
      'mock_sfo_airport': {
        'result': {
          'place_id': 'mock_sfo_airport',
          'formatted_address': 'San Francisco International Airport, San Francisco, CA, USA',
          'name': 'San Francisco International Airport (SFO)',
          'geometry': {
            'location': {'lat': 37.6213, 'lng': -122.3790}
          }
        }
      },
      'mock_lincoln_hs': {
        'result': {
          'place_id': 'mock_lincoln_hs',
          'formatted_address': '2162 24th Ave, San Francisco, CA 94116, USA',
          'name': 'Lincoln High School',
          'geometry': {
            'location': {'lat': 37.7416, 'lng': -122.4810}
          }
        }
      },
      'mock_sf': {
        'result': {
          'place_id': 'mock_sf',
          'formatted_address': 'San Francisco, CA 94103, USA',
          'name': 'San Francisco',
          'geometry': {
            'location': {'lat': 37.7749, 'lng': -122.4194}
          }
        }
      },
      'mock_nyc': {
        'result': {
          'place_id': 'mock_nyc',
          'formatted_address': 'New York, NY 10001, USA',
          'name': 'New York',
          'geometry': {
            'location': {'lat': 40.7128, 'lng': -74.0060}
          }
        }
      },
      'mock_chicago': {
        'result': {
          'place_id': 'mock_chicago',
          'formatted_address': 'Chicago, IL 60601, USA',
          'name': 'Chicago',
          'geometry': {
            'location': {'lat': 41.8781, 'lng': -87.6298}
          }
        }
      },
      'mock_la': {
        'result': {
          'place_id': 'mock_la',
          'formatted_address': 'Los Angeles, CA 90001, USA',
          'name': 'Los Angeles',
          'geometry': {
            'location': {'lat': 34.0522, 'lng': -118.2437}
          }
        }
      },
      'mock_seattle': {
        'result': {
          'place_id': 'mock_seattle',
          'formatted_address': 'Seattle, WA 98101, USA',
          'name': 'Seattle',
          'geometry': {
            'location': {'lat': 47.6062, 'lng': -122.3321}
          }
        }
      },
      'mock_boston': {
        'result': {
          'place_id': 'mock_boston',
          'formatted_address': 'Boston, MA 02108, USA',
          'name': 'Boston',
          'geometry': {
            'location': {'lat': 42.3601, 'lng': -71.0589}
          }
        }
      },
      'mock_miami': {
        'result': {
          'place_id': 'mock_miami',
          'formatted_address': 'Miami, FL 33101, USA',
          'name': 'Miami',
          'geometry': {
            'location': {'lat': 25.7617, 'lng': -80.1918}
          }
        }
      },
      'mock_denver': {
        'result': {
          'place_id': 'mock_denver',
          'formatted_address': 'Denver, CO 80201, USA',
          'name': 'Denver',
          'geometry': {
            'location': {'lat': 39.7392, 'lng': -104.9903}
          }
        }
      },
      'mock_austin': {
        'result': {
          'place_id': 'mock_austin',
          'formatted_address': 'Austin, TX 78701, USA',
          'name': 'Austin',
          'geometry': {
            'location': {'lat': 30.2672, 'lng': -97.7431}
          }
        }
      },
      'mock_san_diego': {
        'result': {
          'place_id': 'mock_san_diego',
          'formatted_address': 'San Diego, CA 92101, USA',
          'name': 'San Diego',
          'geometry': {
            'location': {'lat': 32.7157, 'lng': -117.1611}
          }
        }
      },
      'mock_portland': {
        'result': {
          'place_id': 'mock_portland',
          'formatted_address': 'Portland, OR 97201, USA',
          'name': 'Portland',
          'geometry': {
            'location': {'lat': 45.5051, 'lng': -122.6750}
          }
        }
      },
      'mock_atlanta': {
        'result': {
          'place_id': 'mock_atlanta',
          'formatted_address': 'Atlanta, GA 30301, USA',
          'name': 'Atlanta',
          'geometry': {
            'location': {'lat': 33.7490, 'lng': -84.3880}
          }
        }
      },
      'mock_dallas': {
        'result': {
          'place_id': 'mock_dallas',
          'formatted_address': 'Dallas, TX 75201, USA',
          'name': 'Dallas',
          'geometry': {
            'location': {'lat': 32.7767, 'lng': -96.7970}
          }
        }
      },
      'mock_houston': {
        'result': {
          'place_id': 'mock_houston',
          'formatted_address': 'Houston, TX 77001, USA',
          'name': 'Houston',
          'geometry': {
            'location': {'lat': 29.7604, 'lng': -95.3698}
          }
        }
      },
      'mock_philly': {
        'result': {
          'place_id': 'mock_philly',
          'formatted_address': 'Philadelphia, PA 19101, USA',
          'name': 'Philadelphia',
          'geometry': {
            'location': {'lat': 39.9526, 'lng': -75.1652}
          }
        }
      },
    };

    // Get place details for the given place_id, or default to San Francisco if not found
    final placeDetails =
        mockPlaceDetails[placeId] ?? mockPlaceDetails['mock_sf']!;

    return Place.fromJson(placeDetails);
  }
}
