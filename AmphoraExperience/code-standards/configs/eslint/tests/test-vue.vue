<template>
   <div class="vue-component">
     <h1>{{ title }}</h1>
     <p>Count: {{ count }}</p>
     <button @click="increment">
       Increment
     </button>
     <button :disabled="count <= 0" @click="decrement">
       Decrement
     </button>
     <ul>
       <li v-for="item in items" :key="item.id">
         {{ item.name }}
       </li>
     </ul>
   </div>
 </template>

 <script>
 export default {
   name: 'TestVueComponent',
   props: {
     title: {
       type: String,
       required: true
     },
     initialCount: {
       type: Number,
       default: 0
     }
   },
   data() {
     return {
       count: this.initialCount,
       items: [
        { id: 1, name: 'Item 1' },
         { id: 2, name: 'Item 2' },
         { id: 3, name: 'Item 3' }
       ]
     };
   },
   // Intentional issues for ESLint
   mounted() {
     var unusedVariable = "test";  // var instead of const/let
     let anotherUnused = "also unused";  // missing semicolon
     console.log('Component mounted');
   },
   methods: {
     increment() {
       this.count++;
     },
     decrement() {
       if (this.count > 0) {
         this.count--;
       }
     }
   },
 };
 </script>

 <style scoped>
 .vue-component {
   max-width: 400px;
   margin: 0 auto;
   padding: 20px;
 }

 button {
   margin: 5px;
   padding: 8px 16px;
   background-color: #42b983;
   color: white;
   border: none;
   border-radius: 4px;
   cursor: pointer;
 }

 button:disabled {
   background-color: #ccc;
   cursor: not-allowed;
 }

 button:hover:not(:disabled) {
   background-color: #369970;
 }

 ul {
   list-style-type: none;
   padding: 0;
 }

 li {
   padding: 8px;
   margin: 4px 0;
   background-color: #f0f0f0;
   border-radius: 4px;
 }
 </style>
