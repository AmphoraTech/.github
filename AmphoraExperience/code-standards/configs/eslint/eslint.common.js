// AmphoraExperience/code-standards/configs/eslint/eslint.common.js
import importPlugin from 'eslint-plugin-import';
import globals from 'globals';

export default [
   {
      ignores: [
         '*.md',
         'node_modules/',
         '*.json',
         '.history',
         'dist/',
         'build/',
         '.next/',
         'coverage/',
         'android/',
         'ios/',
         '.expo/'
      ]
   },
   {
      files: ['**/*.js', '**/*.mjs', '**/*.cjs', '**/*.jsx', '**/*.ts', '**/*.tsx'],
      plugins: { 'import': importPlugin },
      languageOptions: {
         ecmaVersion: 2022,
         sourceType: 'module',
         parserOptions: { ecmaFeatures: { jsx: true } },
         globals: {
            ...globals.browser,
            ...globals.node,
            // Additional globals not covered by browser/node
            FormData: 'readonly',
            XMLHttpRequest: 'readonly',
            Vue: 'readonly'
         }
      },
      rules: {
      // Your existing logistics rules
         'object-property-newline': ['error', { allowAllPropertiesOnSameLine: false }],
         'object-curly-newline': ['error', {
            ObjectExpression: {
               multiline: true,
               minProperties: 7
            },
            ObjectPattern: { multiline: true },
            ImportDeclaration: {
               multiline: true,
               minProperties: 7
            },
            ExportDeclaration: {
               multiline: true,
               minProperties: 7
            }
         }],
         'comma-style': ['error', 'last'],
         'comma-dangle': ['error', 'never'],
         'max-len': ['error', { code: 160 }],
         'padding-line-between-statements': [
            'error',
            {
               blankLine: 'always',
               prev: '*',
               next: 'block'
            },
            {
               blankLine: 'always',
               prev: 'block',
               next: '*'
            },
            {
               blankLine: 'always',
               prev: '*',
               next: 'block-like'
            },
            {
               blankLine: 'always',
               prev: 'block-like',
               next: '*'
            },
            {
               blankLine: 'always',
               prev: 'export',
               next: 'block'
            },
            {
               blankLine: 'always',
               prev: 'import',
               next: 'block'
            },
            {
               blankLine: 'always',
               prev: '*',
               next: 'return'
            }
         ],
         'no-var': 'error',
         'prefer-const': ['error', {
            destructuring: 'any',
            ignoreReadBeforeAssign: false
         }],
         // Additional import rules you might want to consider
         'import/no-duplicates': 'error', // Requires eslint-plugin-import
         'sort-imports': ['error', {
            ignoreCase: false,
            ignoreDeclarationSort: true, // Don't sort import declarations
            ignoreMemberSort: false,
            memberSyntaxSortOrder: ['none', 'all', 'multiple', 'single']
         }],
         'object-curly-spacing': ['error', 'always'],
         'space-infix-ops': ['error', { int32Hint: true }],
         'space-before-blocks': 'error',
         'arrow-spacing': 'error',
         'space-before-function-paren': ['error', {
            anonymous: 'never',
            named: 'never',
            asyncArrow: 'always'
         }],
         'arrow-parens': ['error', 'always'],
         'no-dupe-keys': 'off',
         'semi': ['error', 'always'],
         'quotes': ['error', 'single'],
         'indent': ['error', 3],
         'object-shorthand': ['error', 'properties'],
         'no-param-reassign': 'warn',
         'spaced-comment': 'off',
         'no-console': 'warn',
         'consistent-return': 'off',
         'func-names': 'off',
         'no-process-exit': 'off',
         'no-return-await': 'off',
         'no-underscore-dangle': 'off',
         'class-methods-use-this': 'off',
         'prefer-destructuring': ['error', {
            object: true,
            array: false
         }],
         'no-unused-vars': ['error', {
            vars: 'all',
            args: 'all',
            caughtErrors: 'all',
            varsIgnorePattern: '^_',
            argsIgnorePattern: '^_',
            caughtErrorsIgnorePattern: '^_',
            ignoreRestSiblings: true
         }],
         'camelcase': ['warn', {
            allow: [
               'shipping_number',
               'wh_packed',
               'is_printed',
               'created_at',
               'updated_at',
               'user_id',
               'station_id'
            ]
         }]
      }
   }
];
