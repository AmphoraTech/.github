// TypeScript React test file
import React, { useEffect, useState } from 'react';

interface Props {
  title: string;
  count?: number;
}

interface State {
  value: number;
  loading: boolean;
}

const TestTSXComponent: React.FC<Props> = ({ title, count = 0 }) => {
   const [state, setState] = useState<State>({
      value: count,
      loading: false
   });

   useEffect(() => {
      console.log('Component mounted');
   }, []);

   const handleIncrement = (): void => {
      setState((prev) => ({
         ...prev,
         value: prev.value + 1
      }));
   };

   // Intentional issues
   const unusedVar: string = 'test';  // var instead of const
   const anotherUnused = 'also unused';

   return (
      <div>
         <h1>{title}</h1>
         <p>Value: {state.value}</p>
         <button onClick={handleIncrement}>
        Increment
         </button>
         {state.loading && <p>Loading...</p>}
      </div>
   );  // missing semicolon
};

export default TestTSXComponent;
