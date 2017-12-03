import { createStore } from 'reducers';
import rootReducer from './reducers';

let store = createStore(rootReducer);

export default store;