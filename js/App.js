import React, { Component } from 'react';
import { connect } from 'react-redux';
import Login from './components/User/Login.js';
import MainMap from './components/MainMap/App.js';
import Firebase from 'firebase';

class Application extends Component {
  componentWillMount(){
    Firebase.initializeApp({
      apiKey: 'AIzaSyALmrNSukZg4TeIDklKRoKKsCFHivD2SeA',
      authDomain: 'litstop-1508710637497.firebaseapp.com',
      databaseURL: 'https://litstop-1508710637497.firebaseio.com',
      projectId: 'litstop-1508710637497',
      storageBucket: 'litstop-1508710637497.appspot.com',
      messagingSenderId: '431041735118'
    })
  }
  render() {
    if(this.props.isLoggedIn){
      return <MainMap/>;
    }else{
      return <Login/>;
    }
  }
}

const MapStateToProps = (state, props) => {
  return {
    isLoggedIn: state.auth.isLoggedIn
  };
}

export default connect(MapStateToProps)(Application);