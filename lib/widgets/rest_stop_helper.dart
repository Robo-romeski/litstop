import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RestStop {
  final String name;
  final String type;
  final LatLng location;
  final double distance;
  final int rating;

  RestStop({
    required this.name,
    required this.type,
    required this.location,
    required this.distance,
    required this.rating,
  });
}

class RestStopHelper extends StatelessWidget {
  final List<RestStop> nearbyStops;
  final Function(LatLng) onLocationSelected;

  const RestStopHelper({
    super.key,
    required this.nearbyStops,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nearby Rest Stops',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (nearbyStops.isEmpty)
              const Center(
                child: Text('No rest stops found nearby'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nearbyStops.length,
                itemBuilder: (context, index) {
                  final stop = nearbyStops[index];
                  return ListTile(
                    leading: Icon(
                      stop.type == 'gas_station'
                          ? Icons.local_gas_station
                          : Icons.restaurant,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(stop.name),
                    subtitle: Text(
                      '${stop.distance.toStringAsFixed(1)} miles away • ${'⭐' * stop.rating}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.navigation),
                      onPressed: () => onLocationSelected(stop.location),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
