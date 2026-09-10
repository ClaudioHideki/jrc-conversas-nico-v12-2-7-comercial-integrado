import { frontendURL } from 'dashboard/helper/URLHelper';

const VideoConferencePage = () => import('./VideoConferencePage.vue');

export const routes = [
  {
    path: frontendURL('accounts/:accountId/video-conferencia'),
    name: 'video_conference_index',
    component: VideoConferencePage,
    meta: { permissions: ['administrator', 'agent', 'custom_role'] },
  },
];
