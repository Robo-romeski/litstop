import React, { Component } from 'react';
import { StyleSheet, Text } from 'react-native';
import MapView, { PROVIDER_GOOGLE } from 'react-native-maps';
import { Screen, Spinner } from '@shoutem/ui';
import RecommendationsMap from './AreaMap/AreaMap.js';
import StarterMap from './AreaMap/StarterMap.js'
import styles from './AreaMap/styles.js';

export default class AreaMap extends Component {
  state = {
    mapRegion: null,
    gpsAccuracy: null,
    rollup: null
  }
  watchID = null

  componentWillMount() {
    let rollout = 'sheeit mang - im out of bud';
    this.watchID =
    navigator.geolocation.watchPosition((position) => {
      console.log('in position', position);
      let region = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        latitudeDelta: 0.00922*1.5,
        longitudeDelta: 0.00421*1.5
      }
      console.log(region);
      this.setState({
        mapRegion: region,
        gpsAccuracy: position.coords.accuracy,
        rollup: rollout
      });
      console.log(this.state);

      // this.onRegionChange(region, position.coords.accuracy);
    });
  }

  componentWillUnmount() {
    navigator.geolocation.clearWatch(this.watchID);
  }

  // onRegionChange(region, gpsAccuracy) {
  //   this.fetchVenues(region);
  //
  //   this.setState({
  //     mapRegion: region,
  //     gpsAccuracy: gpsAccuracy || this.state.gpsAccuracy
  //   });
  // }

  render() {
    const { mapRegion, lookingFor, gpsAccuracy, rollup } = this.state;

return(
  <Screen>
  <Text>{mapRegion.latitude}</Text>
  </Screen>
);
}

}
