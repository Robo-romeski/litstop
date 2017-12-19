import Firebase from 'firebase';

var config = {
    apiKey: "AIzaSyALmrNSukZg4TeIDklKRoKKsCFHivD2SeA",
    authDomain: "litstop-1508710637497.firebaseapp.com",
    databaseURL: "https://litstop-1508710637497.firebaseio.com",
    projectId: "litstop-1508710637497",
    storageBucket: "litstop-1508710637497.appspot.com",
    messagingSenderId: "431041735118"
  };

  export default Firebase.initializeApp(config);