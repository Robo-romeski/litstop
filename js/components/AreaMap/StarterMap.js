import React, { Component, Text } from 'react';
import MapView from 'react-native-maps'
import { Subtitle, Title } from '@shoutem/ui';
import styles from './styles';
import Recommendation from './Area.js';

const AreaMap = ({ mapRegion, gpsAccuracy, recommendations, lookingFor,
                              headerLocation, onRegionChange, data }) => (

    <MapView.Animated region={mapRegion}
                      style={styles.fullscreen}
                      onRegionChange={onRegionChange}>

        <Title styleName="h-center multiline" style={styles.mapHeader}>
            {lookingFor ? `${lookingFor} in` : ''} {headerLocation}
        </Title>

          {data && data.map((d,i)=> {
            console.log("D", d);
            return(
            <MapView.Marker
            key={i}
    coordinate={d.place.location}
    title={d.category}
    description={d.description}
  />
        )}
      )}


    </MapView.Animated>
);

export default AreaMap;
