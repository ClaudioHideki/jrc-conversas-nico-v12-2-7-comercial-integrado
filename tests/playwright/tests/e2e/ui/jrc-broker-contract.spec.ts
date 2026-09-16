import { test, expect } from '@playwright/test';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve(__dirname, '../../../../..');
const rails = JSON.parse(readFileSync(path.join(root, '.codex/contract/rails-fixture.json'), 'utf8'));
const broker = JSON.parse(readFileSync(path.join(root, '.codex/contract/broker-fixture.json'), 'utf8'));

test('native administrator setup, temporary pairing and account change', async ({ page }, testInfo) => {
  const forbiddenNetwork: string[] = [];
  page.on('request', request => {
    if (/broker\.example\.test|127\.0\.0\.1:3101/.test(request.url())) forbiddenNetwork.push(request.method());
  });
  await page.goto('/app/login');
  await page.getByTestId('email_input').fill(rails.email);
  await page.getByTestId('password_input').fill(rails.password);
  await page.getByTestId('submit_button').click();
  await expect(page).toHaveURL(/\/app\/accounts\/\d+/, { timeout: 60000 });
  await page.goto(`/app/accounts/${rails.accountId}/settings/inboxes/new`);
  await page.getByText('WhatsApp — JRC Broker', { exact: true }).click();
  await expect(page.getByText('Account configuration saved. The stored key cannot be displayed.')).toBeVisible();
  await expect(page.getByLabel('Account control key')).toHaveCount(0);
  await page.getByLabel('Inbox name', { exact: true }).fill(`Synthetic browser ${Date.now()}`);
  await page.getByRole('combobox', { name: 'WhatsApp connection', exact: true }).selectOption('NEW');
  await page.getByLabel('Connection name', { exact: true }).fill(`Browser ${Date.now()}`);
  await page.getByRole('combobox', { name: 'JRC connection service', exact: true }).selectOption(broker.providerId);
  await page.getByLabel('Synthetic Administrator', { exact: true }).check();
  const create = page.getByRole('button', { name: 'Create inbox', exact: true });
  await create.focus();
  await expect(create).toBeFocused();
  // Synthetic account only, captured before requesting any temporary connection code.
  await page.screenshot({ path: path.join(root, `.codex/j5-${testInfo.project.name}-setup.png`) });
  await page.keyboard.press('Enter');
  const pair = page.getByRole('button', { name: 'Get connection code', exact: true });
  await expect(pair).toBeVisible({ timeout: 45000 });
  await pair.click();
  await expect(page.getByText('TESTONLY', { exact: true })).toBeVisible();
  expect(await page.evaluate(() => JSON.stringify({ ...localStorage, ...sessionStorage }))).not.toContain('TESTONLY');
  expect(await page.content()).not.toContain(broker.credential.secret);
  expect(forbiddenNetwork).toEqual([]);
  // Check the feature's section fits the viewport without requiring horizontal scrolling.
  const rect = await pair.boundingBox();
  expect(rect!.x).toBeGreaterThanOrEqual(0);
  expect(rect!.x + rect!.width).toBeLessThanOrEqual(page.viewportSize()!.width);
  await page.goto(`/app/accounts/${rails.otherAccountId}/settings/inboxes/new/jrc_broker`);
  await expect(page.getByText('TESTONLY', { exact: true })).toHaveCount(0);
  await expect(page.getByLabel('Account control key')).toBeVisible();
});
