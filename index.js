import React, { Component } from 'react';
import { AppRegistry, StyleSheet, View } from 'react-native';
import { Provider } from 'react-redux';
import store from './js/store';
// import MapView, { PROVIDER_GOOGLE } from 'react-native-maps';
import App from './js/App.js';

export default class Litstop extends Component {
  render() {
    return (
      <Provider store={store}>
      <App/>
      </Provider>
    );
  }
}

AppRegistry.registerComponent('litstop', ()=> Litstop);
