import { defineConfig } from 'vitest/config';

const TEST_DB = 'volutrainmed_test';
export default defineConfig({
  test: {
    env: {
      DATABASE_ADMIN_URL: `postgres://volutrain:volutrain@localhost:54329/${TEST_DB}`,
      DATABASE_URL: `postgres://vtm_app:vtm_app_dev@localhost:54329/${TEST_DB}`,
      NODE_ENV: 'test',
    },
    globalSetup: ['./test/global-setup.ts'],
    fileParallelism: false,
    testTimeout: 120_000,
    hookTimeout: 300_000,
  },
});
