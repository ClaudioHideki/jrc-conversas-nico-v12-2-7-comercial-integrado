<script setup>
import { computed, h } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import wootConstants from 'dashboard/constants/globals';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useImpersonation } from 'dashboard/composables/useImpersonation';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';
import Icon from 'next/icon/Icon.vue';
import Button from 'next/button/Button.vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

const { t } = useI18n();
const store = useStore();
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserAutoOffline = useMapGetter('getCurrentUserAutoOffline');

const { isImpersonating } = useImpersonation();

const { AVAILABILITY_STATUS_KEYS } = wootConstants;
const statusDefinitions = [
  { label: 'Disponível', value: 'online', color: 'bg-n-teal-9' },
  { label: 'Indisponível', value: 'offline', color: 'bg-n-slate-9' },
  { label: 'Reunião', value: 'meeting', color: 'bg-n-blue-9' },
  { label: 'Feedback', value: 'feedback', color: 'bg-n-violet-9' },
  { label: 'Fim do turno', value: 'end_shift', color: 'bg-n-gray-9' },
  { label: 'Treinamento', value: 'training', color: 'bg-n-purple-9' },
  { label: 'Pausa banheiro', value: 'bathroom_break', color: 'bg-n-cyan-9' },
  { label: 'Pausa almoço', value: 'lunch_break', color: 'bg-n-amber-9' },
  { label: 'Chamada Manual', value: 'manual_call', color: 'bg-n-rose-9' },
];

const availabilityStatuses = computed(() =>
  statusDefinitions
    .filter(status => AVAILABILITY_STATUS_KEYS.includes(status.value))
    .map(status => ({
      ...status,
      icon: h('span', { class: [status.color, 'size-[12px] rounded-full'] }),
      active: currentUserAvailability.value === status.value,
    }))
);

const activeStatus = computed(() => {
  return availabilityStatuses.value.find(status => status.active);
});

const autoOfflineToggle = computed({
  get: () => currentUserAutoOffline.value,
  set: autoOffline => {
    store.dispatch('updateAutoOffline', {
      accountId: currentAccountId.value,
      autoOffline,
    });
  },
});

function changeAvailabilityStatus(availability) {
  if (isImpersonating.value) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
    return;
  }
  try {
    store.dispatch('updateAvailability', {
      availability,
      account_id: currentAccountId.value,
    });
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
  }
}
</script>

<template>
  <DropdownSection class="[&>ul]:overflow-visible [&>ul]:!gap-1">
    <div class="grid gap-1 py-1">
      <DropdownItem
        preserve-open
        class="!rounded-xl !px-3 !py-2.5 hover:!bg-[#edf5fd]"
      >
        <div
          class="flex-grow flex items-center gap-1 min-w-0 text-sm font-medium text-[#173a5e]"
        >
          {{ $t('SIDEBAR.SET_YOUR_AVAILABILITY') }}
        </div>
        <DropdownContainer class="shrink-0">
          <template #trigger="{ toggle }">
            <Button
              size="sm"
              color="slate"
              variant="faded"
              icon="i-lucide-chevron-down"
              trailing-icon
              class="!border-[#d8e4f0] !bg-[#f1f7fd] !text-[#173a5e] hover:!bg-[#e6f1fb]"
              @click="toggle"
            >
              <div class="flex gap-1 items-center min-w-0 text-sm">
                <div class="p-1 flex-shrink-0">
                  <div class="size-2 rounded-sm" :class="activeStatus.color" />
                </div>
                <span class="truncate max-w-[7rem]">
                  {{ activeStatus.label }}
                </span>
              </div>
            </Button>
          </template>
          <DropdownBody
            strong
            class="min-w-36 z-20 [&>ul]:!border-[#d8e4f0] [&>ul]:!bg-white [&>ul]:!shadow-xl [&_.n-dropdown-item>*]:!text-[#173a5e]"
          >
            <DropdownItem
              v-for="status in availabilityStatuses"
              :key="status.value"
              :label="status.label"
              :icon="status.icon"
              class="cursor-pointer"
              @click="changeAvailabilityStatus(status.value)"
            />
          </DropdownBody>
        </DropdownContainer>
      </DropdownItem>
      <DropdownItem class="!rounded-xl !px-3 !py-2.5 hover:!bg-[#edf5fd]">
        <div class="flex-grow min-w-0 text-sm text-[#173a5e]">
          {{ $t('SIDEBAR.SET_AUTO_OFFLINE.TEXT') }}
          <Icon
            v-tooltip.top="$t('SIDEBAR.SET_AUTO_OFFLINE.INFO_SHORT')"
            icon="i-lucide-info"
            class="inline-block align-middle ms-1 size-4 text-n-slate-10"
          />
        </div>
        <ToggleSwitch v-model="autoOfflineToggle" />
      </DropdownItem>
    </div>
  </DropdownSection>
</template>
