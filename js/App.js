import React, { Component } from 'react';
import { connect } from 'react-redux';
import Login from './components/User/Login.js';
import MainMap from './components/MainMap/App.js';

class Application extends Component {
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