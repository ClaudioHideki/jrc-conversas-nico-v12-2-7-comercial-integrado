<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import ButtonNext from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import Logo from 'next/icon/Logo.vue';

import {
  DropdownContainer,
  DropdownBody,
  DropdownSection,
  DropdownItem,
} from 'next/dropdown-menu/base';

defineProps({
  isCollapsed: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['showCreateAccountModal']);

const { t } = useI18n();
const { accountId, currentAccount } = useAccount();
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');

const userAccounts = useMapGetter('getUserAccounts');

const showAccountSwitcher = computed(
  () => userAccounts.value.length > 1 && currentAccount.value.name
);

const sortedCurrentUserAccounts = computed(() => {
  return [...(currentUser.value.accounts || [])].sort((a, b) =>
    a.name.localeCompare(b.name)
  );
});

const onChangeAccount = newId => {
  const accountUrl = `/app/accounts/${newId}/dashboard`;
  window.location.href = accountUrl;
};

const emitNewAccount = () => {
  emit('showCreateAccountModal');
};
</script>

<template>
  <DropdownContainer>
    <template #trigger="{ toggle, isOpen }">
      <!-- Collapsed view: Logo trigger -->
      <button
        v-if="isCollapsed"
        class="grid flex-shrink-0 place-content-center p-2 rounded-lg cursor-pointer hover:bg-n-alpha-1"
        :class="{ 'bg-n-alpha-1': isOpen }"
        :title="currentAccount.name"
        @click="toggle"
      >
        <Logo class="size-7" />
      </button>
      <!-- Expanded view: Account name trigger -->
      <button
        v-else
        id="sidebar-account-switcher"
        :data-account-id="accountId"
        aria-haspopup="listbox"
        aria-controls="account-options"
        class="flex items-center gap-2 justify-between w-full rounded-lg px-2"
        :class="[
          isOpen && 'bg-n-alpha-1',
          showAccountSwitcher
            ? 'hover:bg-n-alpha-1 cursor-pointer'
            : 'cursor-default',
        ]"
        @click="() => showAccountSwitcher && toggle()"
      >
        <span
          class="text-xs font-medium leading-5 text-white/75 truncate"
          aria-live="polite"
        >
          {{ currentAccount.name }}
        </span>

        <span
          v-if="showAccountSwitcher"
          aria-hidden="true"
          class="i-lucide-chevron-down size-4 text-white/75 flex-shrink-0"
        />
      </button>
    </template>
    <DropdownBody
      v-if="showAccountSwitcher || isCollapsed"
      class="top-8 z-50 w-[276px] ltr:left-0 rtl:right-0 [&>ul]:!gap-1 [&>ul]:!rounded-2xl [&>ul]:!border-[#d8e4f0] [&>ul]:!bg-white [&>ul]:!p-2 [&>ul]:!shadow-[0_24px_70px_rgba(2,31,62,0.28)] [&>ul]:!backdrop-blur-none"
    >
      <DropdownSection
        :title="t('SIDEBAR_ITEMS.SWITCH_ACCOUNT')"
        class="[&>div]:!mb-2 [&>div]:!px-3 [&>div]:!pt-1 [&>div]:!font-semibold [&>div]:!text-[#526b85]"
      >
        <DropdownItem
          v-for="account in sortedCurrentUserAccounts"
          :id="`account-${account.id}`"
          :key="account.id"
          class="cursor-pointer !rounded-xl !px-3 !py-2.5 transition-colors hover:!bg-[#edf5fd]"
          @click="onChangeAccount(account.id)"
        >
          <template #label>
            <div
              :for="account.name"
              class="text-left rtl:text-right flex min-w-0 flex-1 gap-2 items-center"
            >
              <span
                class="max-w-32 truncate min-w-0 font-medium text-[#173a5e]"
                :title="account.name"
              >
                {{ account.name }}
              </span>
              <div class="flex-shrink-0 w-px h-3 bg-n-strong" />
              <span
                class="max-w-20 truncate capitalize text-[#6b8097]"
                :title="account.name"
              >
                {{
                  account.custom_role_id
                    ? account.custom_role.name
                    : account.role
                }}
              </span>
            </div>
            <Icon
              v-show="account.id === accountId"
              icon="i-lucide-check"
              class="text-n-teal-11 size-5"
            />
          </template>
        </DropdownItem>
      </DropdownSection>
      <DropdownItem
        v-if="globalConfig.createNewAccountFromDashboard"
        class="!rounded-xl !p-1"
      >
        <ButtonNext
          color="slate"
          variant="faded"
          class="!w-full !rounded-xl !border-[#d8e4f0] !bg-[#f1f7fd] !text-[#173a5e] hover:!bg-[#e6f1fb]"
          size="sm"
          @click="emitNewAccount"
        >
          {{ t('CREATE_ACCOUNT.NEW_ACCOUNT') }}
        </ButtonNext>
      </DropdownItem>
    </DropdownBody>
  </DropdownContainer>
</template>
