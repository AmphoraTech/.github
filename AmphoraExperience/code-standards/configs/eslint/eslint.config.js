// AmphoraExperience/code-standards/configs/eslint/eslint.config.js
import { fixupPluginRules } from '@eslint/compat';
import js from '@eslint/js';
import tsPlugin from '@typescript-eslint/eslint-plugin';
import tsParser from '@typescript-eslint/parser';
import importPlugin from 'eslint-plugin-import';
import reactPlugin from 'eslint-plugin-react';
import reactHooksPlugin from 'eslint-plugin-react-hooks';
import reactNativePlugin from 'eslint-plugin-react-native';
import vuePlugin from 'eslint-plugin-vue';
import vueParser from 'vue-eslint-parser';
import commonConfig from './eslint.common.js';

export default [
   // Base JavaScript recommended rules
   js.configs.recommended,

   // Common custom rules
   ...commonConfig,

   // TypeScript files
   {
      files: ['**/*.ts', '**/*.tsx'],
      plugins: { '@typescript-eslint': tsPlugin },
      languageOptions: {
         parser: tsParser,
         parserOptions: {
            ecmaVersion: 'latest',
            sourceType: 'module'
         },
         globals: {
            __DEV__: 'readonly',
            fetch: 'readonly',
            navigator: 'readonly'
         }
      },
      rules: {
         ...tsPlugin.configs.recommended.rules,
         '@typescript-eslint/explicit-function-return-type': 'error',
         '@typescript-eslint/explicit-module-boundary-types': 'error',
         '@typescript-eslint/no-explicit-any': 'warn'
      }
   },

   // React / React Native files
   {
      files: ['**/*.jsx', '**/*.tsx'],
      plugins: {
         react: reactPlugin,
         'react-hooks': fixupPluginRules(reactHooksPlugin),
         'react-native': fixupPluginRules(reactNativePlugin),
         '@typescript-eslint': tsPlugin,
         'import': importPlugin  // Add import plugin for React files too
      },
      languageOptions: {
         parser: tsParser, // Needed for TSX
         parserOptions: {
            ecmaVersion: 'latest',
            sourceType: 'module',
            ecmaFeatures: { jsx: true }
         },
         globals: {
            __DEV__: 'readonly',
            fetch: 'readonly',
            navigator: 'readonly',
            ...commonConfig[1].languageOptions.globals  // Include common globals
         }
      },
      rules: {
      // Include common rules first
         ...commonConfig[1].rules,

         // React-specific rules
         ...reactPlugin.configs.recommended.rules,
         'react/react-in-jsx-scope': 'off', // Modern React doesn't need this
         'react/prop-types': 'off', // TS handles types
         'react/jsx-filename-extension': ['error', { extensions: ['.jsx', '.tsx'] }],

         // React Hooks
         'react-hooks/rules-of-hooks': 'error',
         'react-hooks/exhaustive-deps': 'warn',

         // React Native
         'react-native/no-unused-styles': 'error',
         'react-native/no-inline-styles': 'warn',
         'react-native/no-raw-text': 'error',
         'react-native/split-platform-components': 'warn',

         // Enhanced unused imports handling
         'no-unused-vars': ['error', {
            vars: 'all',
            args: 'after-used',
            ignoreRestSiblings: true,
            argsIgnorePattern: '^_',
            varsIgnorePattern: '^_'
         }],
         'import/no-unused-modules': 'warn'
      },
      settings: {
         react: { version: 'detect' },
         'import/resolver': { node: { extensions: ['.js', '.jsx', '.ts', '.tsx'] } }
      }
   },

   // Vue files
   {
      files: ['**/*.vue'],
      plugins: {
         vue: vuePlugin,
         'import': importPlugin
      },
      languageOptions: {
         parser: vueParser, // Required to parse Vue SFCs
         parserOptions: {
            ecmaVersion: 'latest',
            sourceType: 'module'
         },
         // Also copy globals from common config
         globals: { ...commonConfig[1].languageOptions.globals }
      },
      rules: {
         ...commonConfig[1].rules, // Get the rules from the second object in commonConfig array
         ...vuePlugin.configs.recommended.rules,
         'vue/multi-word-component-names': 'off',
         'vue/no-v-html': 'warn',
         'vue/require-default-prop': 'off',
         'vue/require-explicit-emits': 'error',
         'vue/component-name-in-template-casing': ['error', 'PascalCase']
      }
   }
];
