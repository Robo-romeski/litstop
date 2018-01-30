import React, { Component } from 'react';
import { connect } from 'react-redux';
import { login } from '../../store/actions/auth';
import {  Button, AsyncStorage } from 'react-native';
import { TextInput, Card, ScrollView, Image, View, Subtitle, Text, Caption } from '@shoutem/ui';
// import firebase from 'firebase';
import { firebaseRef } from '../../firebase';

class Login extends Component {
    constructor(props){
        super(props);
        this.state = {
            route: 'Login',
            email: '',
            username: '',
            password: ''
        };
    }

    componentWillMount(){
        // firebaseRef.auth().onAuthStateChanged((user)=>{
        //     if(user){
        //         console.log(user, "user is logged in")
        //     }
        // });
    }

    

    firebaseLogin(e){
        firebaseRef.auth().signInWithEmailAndPassword(this.state.email, this.state.password).then((res=>{
            console.log(res, "response");
            AsyncStorage.setItem("user", res.uid)
            this.props.login();
        })).catch((error)=>{
            e.preventDefault();
            console.log(error.code);
            console.log(error.message);
        });
    }
    

    userLogin(e) {
        this.props.onLogin(this.state.username, this.state.password);
        e.preventDefault();
    }

    toggleRoute (e) {
        let alt = (this.state.route === 'Login') ? 'SignUp' : 'Login';
        this.setState({ route: alt });
        e.preventDefault();
    }
    render () {
        let alt = (this.state.route === 'Login') ? 'SignUp' : 'Login';
        return (
            <ScrollView style={{padding: 20}}>
                <Text style={{fontSize: 27}}>{this.state.route}</Text>
                <TextInput 
                    placeholder='Username'
                    autoCapitalize='none'
                    autoCorrect={false} 
                    autoFocus={true} 
                    keyboardType='email-address'
                    value={this.state.email} 
                    onChangeText={(text) => this.setState({ email: text })} />
                <TextInput 
                    placeholder='Password'
                    autoCapitalize='none'
                    autoCorrect={false} 
                    secureTextEntry={true} 
                    value={this.state.password} 
                    onChangeText={(text) => this.setState({ password: text })} />
                <View style={{margin: 7}}/>
                <Button onPress={(e) => this.firebaseLogin(e)} title={this.state.route}/>
                <Text style={{fontSize: 16, color: 'blue'}} onPress={(e) => this.toggleRoute(e)}>{alt}</Text>
            </ScrollView>
        );
    }
}
 
 
const mapStateToProps = (state, ownProps) => {
    return {
        isLoggedIn: state.auth.isLoggedIn
    };
}
 
const mapDispatchToProps = (dispatch) => {
    return {
        onLogin: (username, password) => { dispatch(login(username, password)); },
        onSignUp: (username, password) => { dispatch(signup(username, password)); }
    }
}
 
export default connect(mapStateToProps, mapDispatchToProps)(Login);
