// eslint.config.js - Extends common + adds framework support
import typescriptPlugin from '@typescript-eslint/eslint-plugin';
import typescriptParser from '@typescript-eslint/parser';
import reactPlugin from 'eslint-plugin-react';
import reactHooksPlugin from 'eslint-plugin-react-hooks';
import reactNativePlugin from 'eslint-plugin-react-native';
import vuePlugin from 'eslint-plugin-vue';
import fs from 'fs';
import path from 'path';
import vueParser from 'vue-eslint-parser';
import commonConfig from './eslint.common.js';

// Auto-detect project type
const detectProjectType = () => {
   try {
      // Look for package.json in current directory and parent directories
      let packagePath = path.join(process.cwd(), 'package.json');
      let currentDir = process.cwd();

      // Check up to 3 parent directories for package.json
      for (let i = 0; i < 3; i++) {
         if (fs.existsSync(packagePath)) break;
         currentDir = path.dirname(currentDir);
         packagePath = path.join(currentDir, 'package.json');
      }

      if (!fs.existsSync(packagePath)) {
         // If no package.json found, check for Vue files in current directory
         const vueFiles = fs.readdirSync(process.cwd()).filter(file => file.endsWith('.vue'));
         if (vueFiles.length > 0) return 'vue';
         return 'javascript';
      }

      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      const deps = {
         ...pkg.dependencies,
         ...pkg.devDependencies
      };

      if (deps['react-native']) return 'react-native';
      if (deps['vue']) return 'vue';
      if (deps['react']) return 'react';
      if (deps['typescript'] || fs.existsSync(path.join(currentDir, 'tsconfig.json'))) return 'typescript';

      // Check for Vue files in current directory as fallback
      const vueFiles = fs.readdirSync(process.cwd()).filter(file => file.endsWith('.vue'));
      if (vueFiles.length > 0) return 'vue';

      return 'javascript';
   } catch {
      // Check for Vue files in current directory as fallback
      try {
         const vueFiles = fs.readdirSync(process.cwd()).filter(file => file.endsWith('.vue'));
         if (vueFiles.length > 0) return 'vue';
      } catch {
         // Ignore errors
      }
      return 'javascript';
   }
};

const projectType = detectProjectType();
const config = [...commonConfig];

// UNIVERSAL REACT CONFIGURATION - Apply to ALL JS/TS files that might contain JSX
config.push({
   files: ['**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx'],
   plugins: {
      'react': reactPlugin,
      'react-hooks': reactHooksPlugin,
      '@typescript-eslint': typescriptPlugin // Add the TypeScript plugin here
   },
   languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      parser: typescriptParser, // Use TS parser for better compatibility
      parserOptions: {
         ecmaFeatures: { jsx: true },
         jsx: true,
         project: false // Don't require tsconfig for basic JSX parsing
      }
   },
   rules: {
      // Essential React JSX rules
      'react/jsx-uses-vars': 'error', // This marks JSX components as "used"
      'react/jsx-uses-react': 'off', // Not needed in modern React
      'react/react-in-jsx-scope': 'off', // Not needed in modern React

      // Turn off conflicting unused vars rules
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['error', {
         varsIgnorePattern: '^_',
         argsIgnorePattern: '^_',
         ignoreRestSiblings: true,
         vars: 'all',
         args: 'after-used'
      }]
   },
   settings: { react: { version: 'detect' } }
});

// Add React Native specific rules (extends the universal config above)
if (projectType === 'react-native') {
   console.log('React Native project detected');
   config.push({
      files: ['**/*.jsx', '**/*.tsx'],
      plugins: {
         'react': reactPlugin,
         'react-hooks': reactHooksPlugin,
         'react-native': reactNativePlugin
      },
      languageOptions: {
         ecmaVersion: 2022,
         sourceType: 'module',
         parser: typescriptParser,
         parserOptions: {
            ecmaFeatures: { jsx: true },
            jsx: true
         },
         globals: {
            __DEV__: 'readonly',
            navigator: 'readonly'
         }
      },
      rules: {
         ...reactPlugin.configs.recommended.rules,
         ...reactHooksPlugin.configs.recommended.rules,

         // React Native specific
         'react-native/no-unused-styles': 'error',
         'react-native/no-inline-styles': 'warn',
         'react-native/no-color-literals': 'warn',
         'react-native/no-raw-text': 'error',

         // React rules
         'react/prop-types': 'off',
         'react/jsx-pascal-case': 'error',
         'react/jsx-no-duplicate-props': 'error',

         // More lenient console for RN debugging
         'no-console': 'warn'
      }
   });
}

// Add React Web specific rules (extends the universal config above)
if (projectType === 'react') {
   console.log('React project detected');
   config.push({
      files: ['**/*.jsx', '**/*.tsx'],
      plugins: {
         'react': reactPlugin,
         'react-hooks': reactHooksPlugin
      },
      languageOptions: {
         ecmaVersion: 2022,
         sourceType: 'module',
         parser: typescriptParser,
         parserOptions: {
            ecmaFeatures: { jsx: true },
            jsx: true
         }
      },
      rules: {
         ...reactPlugin.configs.recommended.rules,
         ...reactHooksPlugin.configs.recommended.rules,

         // React rules
         'react/prop-types': 'off',
         'react/jsx-pascal-case': 'error',
         'react/jsx-no-duplicate-props': 'error',

         // Stricter console for web
         'no-console': 'error'
      }
   });
}

// Add Vue specific rules
if (projectType === 'vue') {
   console.log('Vue project detected');
   config.push({
      files: ['**/*.vue'],
      plugins: { 'vue': vuePlugin },
      languageOptions: {
         parser: vueParser,
         parserOptions: {
            parser: typescriptParser,
            extraFileExtensions: ['.vue']
         }
      },
      rules: {
         ...vuePlugin.configs['vue3-recommended'].rules,

         // Vue specific
         'vue/multi-word-component-names': 'off',
         'vue/no-v-html': 'warn',
         'vue/require-default-prop': 'off',
         'vue/require-explicit-emits': 'error',
         'vue/component-name-in-template-casing': ['error', 'PascalCase'],

         // Common rules for Vue files
         'no-var': 'error',
         'prefer-const': ['error', {
            destructuring: 'any',
            ignoreReadBeforeAssign: false
         }],
         'no-unused-vars': ['error', {
            varsIgnorePattern: '^_',
            argsIgnorePattern: '^_',
            ignoreRestSiblings: true
         }],

         // Stricter console for web
         'no-console': 'error'
      }
   });
}

config.push({
   files: ['**/*.ts', '**/*.tsx'],
   plugins: { '@typescript-eslint': typescriptPlugin },
   languageOptions: {
      parser: typescriptParser,
      parserOptions: {
         ecmaFeatures: { jsx: true },
         jsx: true
      }
   },
   rules: {
      ...typescriptPlugin.configs.recommended.rules,
      '@typescript-eslint/explicit-function-return-type': 'error',
      '@typescript-eslint/explicit-module-boundary-types': 'error',
      '@typescript-eslint/no-explicit-any': 'warn'
   }
});

export default config;
