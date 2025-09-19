import typescriptPlugin from '@typescript-eslint/eslint-plugin';
import importPlugin from 'eslint-plugin-import';

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
      plugins: { '@typescript-eslint': typescriptPlugin, 'import': importPlugin },
      languageOptions: {
         ecmaVersion: 2022,
         sourceType: 'module',
         parserOptions: { ecmaFeatures: { jsx: true } },
         globals: {
            window: 'readonly',
            document: 'readonly',
            console: 'readonly',
            fetch: 'readonly',
            localStorage: 'readonly',
            sessionStorage: 'readonly',
            process: 'readonly',
            Buffer: 'readonly',
            __dirname: 'readonly',
            __filename: 'readonly',
            module: 'readonly',
            require: 'readonly',
            exports: 'readonly',
            global: 'readonly',
            __DEV__: 'readonly',
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
               minProperties: 3
            },
            ObjectPattern: { multiline: true },
            ImportDeclaration: {
               multiline: true,
               minProperties: 3
            },
            ExportDeclaration: {
               multiline: true,
               minProperties: 3
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
            varsIgnorePattern: '^_',
            argsIgnorePattern: '^_',
            ignoreRestSiblings: true
         }],
         'camelcase': ['error', {
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
