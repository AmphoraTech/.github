// React JSX test file
import React, { useState } from 'react';

function TestComponent({ title }) {
   const [count, setCount] = useState(0);

   const handleClick = () => {
      setCount(count + 1);
   };

   // Intentional ESLint errors
   const unusedVar = 'test';  // var instead of const and unused var
   var preferConst = 'test';  // var instead of const and unused var

   return (
      <div>
         {preferConst}
         <h1>{title}</h1>
         <p>Count: {count}</p>
         <button onClick={handleClick}>
        Increment
         </button>
      </div>
   );
}

// Missing prop validation
export default TestComponent;
