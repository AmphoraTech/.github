// React Native test file
import React, { useState } from 'react';
import {
   Alert, Image, Pressable, StyleSheet, Text, TouchableOpacity, View
} from 'react-native';

const TestReactNative = () => {
   const [count, setCount] = useState(0);

   const onPress = () => {
      setCount(count + 1);
      Alert.alert('Button Pressed', `Count is now ${count + 1}`);
   };

   // Intentional issues for ESLint
   var unused = 'unused';  // var + unused variable
   const anotherUnused = 'test'  // missing semicolon

   return (
      <View style={styles.container}>
         <Text style={styles.title}>React Native Test</Text>
         <Text style={styles.counter}>Count: {count}</Text>
         <TouchableOpacity style={styles.button} onPress={onPress}>
            <Text style={styles.buttonText}>Press Me</Text>
         </TouchableOpacity>
      </View>
   );
};

const styles = StyleSheet.create({
   container: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: '#F5FCFF'
   },
   title: {
      fontSize: 20,
      textAlign: 'center',
      margin: 10
   },
   counter: {
      fontSize: 16,
      textAlign: 'center',
      marginBottom: 20
   },
   button: {
      backgroundColor: '#007AFF',
      padding: 10,
      borderRadius: 5
   },
   buttonText: {
      color: 'white',
      fontSize: 16
   },
   buttonUnused: {
      color: 'white',
      fontSize: 16
   }
});

export default TestReactNative;
