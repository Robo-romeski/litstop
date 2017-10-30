import React, { Component } from 'react';
import { AppRegistry, StyleSheet, View } from 'react-native';
// import MapView, { PROVIDER_GOOGLE } from 'react-native-maps';
import App from './components/App.js';
export default class Litstop extends Component {
  render() {
    return (
      <App/>
    );
  }
}

AppRegistry.registerComponent('litstop', ()=> Litstop);
