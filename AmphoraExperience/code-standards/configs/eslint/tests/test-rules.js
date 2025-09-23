import { useEffect, useState } from 'react';

// Test PropTypes rule - should show error since prop-types is enforced
function ComponentWithoutPropTypes({ title, count }) {
   return (
      <View>
         <Text>{title}</Text>
         <Text>{count}</Text>
      </View>
   );
}

// Test various formatting and code style rules
const TestComponent = () => {
   const [counter, setCounter] = useState(0);
   const [items, setItems] = useState([]);

   // Test no-console rule - should show warning/error
   console.log('This should trigger no-console rule');
   console.warn('Warning message');
   console.error('Error message');

   // Test no-var rule - should show error
   const oldStyleVariable = 'should be const/let';

   // Test prefer-const rule - should show error since it's never reassigned
   const shouldBeConst = 'never changes';

   // Test no-unused-vars rule - should show error (unless starts with _)
   var unusedVariable = 'not used anywhere';
   const _intentionallyUnused = 'this is okay because starts with _';

   // Test object-property-newline and object-curly-newline rules
   const badObject = {prop1: 'value1', prop2: 'value2',prop3: 'value3',prop4: 'value4',prop5: 'value5',prop6: 'value6',prop7: 'value7'};

   const goodObject = {
      prop1: 'value1',
      prop2: 'value2',
      prop3: 'value3',
      prop4: 'value4',
      prop5: 'value5',
      prop6: 'value6',
      prop7: 'value7'
   };

   const test = (arg1, arg2) => {
      console.log(arg1);
      return 'test';
   };

   // Test spacing rules
   const spacingTest = () => {return'bad spacing';}; // Should trigger multiple spacing rules

   const goodSpacing = () => { return 'good spacing'; };

   // Test arrow-parens rule
   const badArrow = (x) => x * 2; // Should require parentheses around parameter
   const goodArrow = (x) => x * 2;

   // Test quotes rule (should use single quotes)
   const doubleQuotedString = "should be single quotes";
   const singleQuotedString = 'this is correct';

   // Test semicolon rule
   const missingSemicolon = 'missing semicolon' // Should show error
   const hasSemicolon = 'has semicolon';

   // Test indent rule (should be 3 spaces)
  const wrongIndent = 'only 2 spaces';
   const correctIndent = 'has 3 spaces';

   // Test max-len rule (line longer than 160 characters)
   const veryLongLineTestThatShouldTriggerMaxLengthRuleWhenItExceedsTheConfiguredLimitOf160CharactersWhichShouldCauseAnESLintErrorToBeShownInTheEditor = 'too long';

   // Test comma-dangle rule (should have no trailing commas)
   const arrayWithTrailingComma = [
      'item1',
      'item2',
      'item3', // This trailing comma should trigger error
   ];

   // Test React Hooks rules
   useEffect(() => {
      // Test exhaustive-deps rule - missing dependency should show warning
      console.log(counter);
   }, []); // Missing 'counter' in dependency array

   // Test rules-of-hooks rule - conditional hook usage should show error
   if (counter > 5) {
      // This should trigger rules-of-hooks error
      const [conditionalState] = useState('wrong');
   }

   // Test camelcase rule with allowed exceptions
   const shipping_number = '12345'; // Should be allowed
   const badCamelCase = 'bad_variable_name'; // Should show error
   const goodCamelCase = 'goodVariableName';

   // Test prefer-destructuring rule
   const user = {
      name: 'John',
      age: 30
   };
   const userName = user.name; // Should suggest destructuring
   const { name } = user; // This is the preferred way

   // Test object-shorthand rule
   const _userName = 'John';
   const badShorthand = { name: userName }; // Should use shorthand
   const goodShorthand = { name: userName };

   const handlePress = () => {
      setCounter(counter + 1);

      // Test padding-line-between-statements rule
       const temp = 'should have blank line before this block';

      if (counter > 10) {
         Alert.alert('Counter is high!');
      }

      return counter; // Should have blank line before return
   };

   return <></>;
};

export default TestComponent;
