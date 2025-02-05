import { test, expect } from '@playwright/test';

const SITE_URL = 'https://app.associateattorney.ai';
// const SITE_URL = 'http://localhost';

// Generate random 6-digit numbers for title and description
const randomNumber = Math.floor(100000 + Math.random() * 900000);
const taskTitle = `Test Task Title ${randomNumber}`;
const taskDescription = `This is a test task description ${randomNumber}`;

test.describe('Task Creation and Comment Flow', () => {

    test.beforeEach(async ({ page }) => {
        await page.goto(`${SITE_URL}/login`); 
        await page.fill('input[type="email"]','soumen+040225@grmtech.com'); 
        await page.fill('input[type="password"]', 'jaikalima99'); 
        await page.click('.submit-button'); 
        await page.waitForURL(`${SITE_URL}/all-matters/dashboard`);
    });

    test('1. task create test', async ({ page }) => {
        // Navigate to the tasks page
        await page.goto(`${SITE_URL}/single-matter/3/tasks`); 
        await page.waitForLoadState('networkidle');
        await expect(page).toHaveURL(`${SITE_URL}/single-matter/3/tasks`);
        
        // Click the New Task button to open the create task dialog
        await page.click('button:has-text("New Task")');
        
        // Verify the Create New Task dialog is visible
        await expect(page.locator('.create-task-dialog')).toBeVisible();

        // Fill in the task title with random number
        await page.fill('.create-task-dialog input', taskTitle);

        // Fill in the task description with random number using TipTap editor
        await page.locator('.create-task-dialog .tiptap').fill(taskDescription);

        // Click the Create button
        await page.click('.create-task-dialog .dialog-footer button:has-text("Create")');

        // Wait for the dialog to close and verify success message
        await expect(page.locator('.create-task-dialog')).not.toBeVisible();
        await expect(page.locator('.el-message--success')).toBeVisible();

        // Verify the task appears in the tasks hierarchy
        //await expect(page.locator('.tasks-hierarchy .task-card')).toBeVisible();
        const taskInList = page.locator('.tasks-hierarchy .task-card .task-title', { hasText: taskTitle });
        await expect(taskInList).toBeVisible();
    });

    test('2. task create comment test', async ({ page }) => {
        // Navigate to the tasks page
        await page.goto(`${SITE_URL}/single-matter/3/tasks`); 
        await page.waitForLoadState('networkidle');
        await expect(page).toHaveURL(`${SITE_URL}/single-matter/3/tasks`);
        await page.reload();
        await page.waitForLoadState('networkidle');

        // Wait for the tasks hierarchy to be visible
        await expect(page.locator('.tasks-hierarchy')).toBeVisible();
        
        // Find and right-click the specific task
        //const taskTitleLocator = page.locator('.tasks-hierarchy .task-card .task-title', { hasText: taskTitle });
        const taskTitleLocator = page.locator('.tasks-hierarchy .task-card .task-title').first();
        await expect(taskTitleLocator).toBeVisible();
        await taskTitleLocator.click({ button: 'right' });
        
        await page.waitForLoadState('networkidle');
        // Fill in the comment text
        await page.fill('.tiptap', 'This is a test comment');

        // Click the "Add Comment" button
        await page.click('button:has-text("Add Comment")');

        // Verify the comment is added successfully
        await expect(page.locator('.el-message--success')).toBeVisible();
    });
});
