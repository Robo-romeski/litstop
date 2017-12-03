import React, { Component } from 'react';
import { StyleSheet, Text } from 'react-native';
import MapView, { PROVIDER_GOOGLE } from 'react-native-maps';
import { Screen, Spinner } from '@shoutem/ui';
import CenterMap from './components/AreaMap/AreaMap.js';
import StarterMap from './components/AreaMap/StarterMap.js'
import styles from './components/AreaMap/styles.js';
import SpeechNotification from 'react-native-speech-notification';
import axios from 'axios';

let words = 'whats popping Devin!';
const API_END_POINT = 'https://localhost:7000/events?lat=40.660672&lng=-73.877380&distance=10'

export default class AreaMap extends Component {
  state = {
    mapRegion: null,
    gpsAccuracy: null,
  }
  watchID = null

  componentWillMount() {
    // let rollout = 'sheeit mang - im out of bud';
    this.watchID =
    navigator.geolocation.watchPosition((position) => {
      console.log('in position', position);
      let region = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        latitudeDelta: 0.00922*1.5,
        longitudeDelta: 0.00421*1.5
      }
      this.setState({
        Watchlat: position.coords.latitude,
        Watchlng: position.coords.longitude,
        mapRegion: region,
        gpsAccuracy: position.coords.accuracy,
      });
      axios.get('http://localhost:7000/events', {
        params: {
          lat: this.state.Watchlat,
          lng: this.state.Watchlng,
          distance: 100,
        }
      }).then((response) => {
        console.log('respond', response);
        this.setState({
          data: response.data
        })
      }).catch(err => console.log(err));

      // this.onRegionChange(region, position.coords.accuracy);
    });
  }

  componentWillUnmount() {
    navigator.geolocation.clearWatch(this.watchID);
  }

  componentDidMount() {
//     SpeechNotification.speak({
//   message: words
// });
  }

  onRegionChange(region, gpsAccuracy){
    // this.hitUpAPI(region);

    this.setState({
      mapRegion: region,
      gpsAccuracy: gpsAccuracy || this.state.gpsAccuracy
    });
  }



  // hitUpAPI(lat, lng, distance) {
  //   axios.get('https://litstop.herokuapp.com/events', {
  //     params: {
  //       lat: this.state.Watchlat,
  //       lng: this.state.Watchlng,
  //       distance: 100,
  //     }
  //   }).then((response) => {
  //     console.log('respond', response);
  //     this.setState({
  //       data: response.data
  //     })
  //   });
  // }

  render() {
    console.log('State of Mind',this.state);
    const { mapRegion, lookingFor, gpsAccuracy, rollup, lat, lng, data } = this.state;
    console.log('State of the Union',mapRegion);
    console.log('dadat',data);


return(
  <Screen>
<StarterMap {...this.state} />
  {mapRegion &&
    <Text> {mapRegion.latitude}, {mapRegion.longitude}</Text>
  }
  </Screen>
);
}

}
