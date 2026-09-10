<script setup>
import { useRoute } from 'vue-router';
import JrcCampaignsPage from './JrcCampaignsPage.vue';

const route = useRoute();
</script>

<template>
  <JrcCampaignsPage :key="route.params.accountId" />
</template>
