import React, { Component } from 'react';
import { AsyncStorage } from 'react-native';
import { connect } from 'react-redux';
import Login from './components/User/Login.js';
import MainMap from './components/MainMap/App.js';
import Firebase from 'firebase';
import { firebaseRef } from './firebase';

class Application extends Component {
  constructor(props) {
    super(props);
    this.state = {
      firebaseUserLoggedIn: false
    }
  }
  componentWillMount = async () => {
    const user = await AsyncStorage.getItem("user");
    console.log(user);
    if (user) {
      this.setState({
        firebaseUserLoggedIn: true
      })
    }
    AsyncStorage.removeItem("user");
  }


  login = () => {
    this.setState({
      firebaseUserLoggedIn: true
    })
  }



  render() {
    if (this.state.firebaseUserLoggedIn) {
      return <MainMap />;
    } else {
      return <Login login={this.login} />;
    }
  }
}

const MapStateToProps = (state, props) => {
  return {
    isLoggedIn: state.auth.isLoggedIn
  };
}

export default connect(MapStateToProps)(Application);