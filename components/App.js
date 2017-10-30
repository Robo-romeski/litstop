import React, { Component, PropTypes } from 'react';
import { StyleSheet, Text } from 'react-native';
import MapView, { PROVIDER_GOOGLE } from 'react-native-maps';
import { Screen, Spinner } from '@shoutem/ui';
import RecommendationsMap from './AreaMap/AreaMap.js';
import styles from './AreaMap/styles.js';

export default class AreaMap extends Component {
  state = {
    mapRegion: null,
    gpsAccuracy: null
  }
  watchID = null

  componentWillMount() {
    this.watchID =
    navigator.geolocation.watchPosition((position) => {
      let region = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        latitudeDelta: 0.00922*1.5,
        longitudeDelta: 0.00421*1.5
      }

      this.onRegionChange(region, position.coords.accuracy);
    });
  }

  componentWillUnmount() {
    navigator.geolocation.clearWatch(this.watchID);
  }

  onRegionChange(region, gpsAccuracy) {
    this.fetchVenues(region);

    this.setState({
      mapRegion: region,
      gpsAccuracy: gpsAccuracy || this.state.gpsAccuracy
    });
  }

  render() {
    const { mapRegion, lookingFor } = this.state;

return(
  <RecommendationsMap />
);
}

}
