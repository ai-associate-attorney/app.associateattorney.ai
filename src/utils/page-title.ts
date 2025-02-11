export const setPageTitle = (title: string) => {
    document.title = title ? `${title} | TaskManager` : 'TaskManager';
};