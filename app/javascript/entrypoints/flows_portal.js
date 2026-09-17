import { createApp, h } from 'vue';
import { createRouter, createWebHistory, RouterView } from 'vue-router';
import { createI18n } from 'vue-i18n';
import { createStore } from 'vuex';
import FlowsPortal from 'dashboard/routes/dashboard/jrcFlows/portal/FlowsPortal.vue';
import 'dashboard/assets/scss/app.scss';

const router = createRouter({
  history: createWebHistory(),
  routes: [{ path: '/:pathMatch(.*)*', component: FlowsPortal }],
});
const app = createApp({ render: () => h(RouterView) });
app.use(router);
app.use(
  createI18n({
    legacy: false,
    locale: 'pt_BR',
    messages: {
      pt_BR: {
        DIALOG: { BUTTONS: { CANCEL: 'Cancelar', CONFIRM: 'Confirmar' } },
      },
    },
  })
);
app.use(createStore({ getters: { 'accounts/isRTL': () => false } }));
app.mount('#flows-portal');
