<script setup>
import { computed, ref, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import SalesAPI from 'dashboard/api/sales';
import SalesOpportunityForm from './SalesOpportunityForm.vue';
import SalesActivityForm from './SalesActivityForm.vue';
import { useAlert } from 'dashboard/composables';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';

const props = defineProps({
  opportunityId: { type: [Number, String], default: null },
  stages: { type: Array, required: true },
  lossReasons: { type: Array, required: true },
});
const emit = defineEmits(['close', 'changed']);
const route = useRoute();
const router = useRouter();
const opportunity = ref(null);
const loading = ref(false);
const showEdit = ref(false);
const showActivity = ref(false);
const editingActivity = ref(null);
const selectedStageId = ref('');
const selectedLossReasonId = ref('');
const lossNotes = ref('');

const selectedStage = computed(() =>
  props.stages.find(stage => Number(stage.id) === Number(selectedStageId.value))
);

const load = async () => {
  if (!props.opportunityId) return;
  loading.value = true;
  try {
    const { data } = await SalesAPI.opportunity(props.opportunityId);
    opportunity.value = data;
    selectedStageId.value = data.stage.id;
    selectedLossReasonId.value = data.loss_reason?.id || '';
    lossNotes.value = data.loss_notes || '';
  } finally {
    loading.value = false;
  }
};

const move = async () => {
  try {
    await SalesAPI.moveOpportunity(opportunity.value.id, {
      stage_id: selectedStageId.value,
      loss_reason_id: selectedLossReasonId.value || null,
      loss_notes: lossNotes.value,
    });
    await load();
    emit('changed');
  } catch (error) {
    useAlert(
      error.response?.data?.message || 'Não foi possível alterar a etapa.'
    );
    selectedStageId.value = opportunity.value.stage.id;
  }
};

const updateActivity = activity => {
  editingActivity.value = activity;
  showActivity.value = true;
};

const activitySaved = async () => {
  showActivity.value = false;
  editingActivity.value = null;
  await load();
  emit('changed');
};

const archive = async () => {
  await SalesAPI.archiveOpportunity(opportunity.value.id);
  emit('changed');
  emit('close');
};

const openConversation = () => {
  if (!opportunity.value.conversation_display_id) return;
  router.push(
    `/app/accounts/${route.params.accountId}/conversations/${opportunity.value.conversation_display_id}`
  );
};

const openContact = () => {
  router.push(
    `/app/accounts/${route.params.accountId}/contacts/${opportunity.value.contact.id}`
  );
};

const openCallHistory = () => {
  router.push({
    name: 'ramal_index',
    params: { accountId: route.params.accountId },
  });
};

watch(() => props.opportunityId, load, { immediate: true });
</script>

<template>
  <Teleport to="body">
    <div
      v-if="opportunityId"
      class="fixed inset-0 z-[65] flex justify-end bg-black/30"
      @click.self="$emit('close')"
    >
      <aside
        class="h-full w-full max-w-2xl overflow-y-auto bg-n-solid-2 shadow-2xl"
      >
        <header
          class="sticky top-0 z-10 flex items-center justify-between border-b border-n-weak bg-n-solid-2 px-6 py-4"
        >
          <h2 class="truncate text-lg font-semibold text-n-slate-12">
            {{ opportunity?.title || $t('SALES.LOADING') }}
          </h2>
          <button
            type="button"
            class="i-lucide-x size-5 text-n-slate-11"
            :aria-label="$t('SALES.CLOSE')"
            @click="$emit('close')"
          />
        </header>
        <div v-if="loading" class="p-8 text-center text-n-slate-11">
          {{ $t('SALES.LOADING') }}
        </div>
        <div v-else-if="opportunity" class="space-y-6 p-6">
          <div class="flex flex-wrap gap-2">
            <button
              type="button"
              class="rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-white"
              @click="showEdit = true"
            >
              {{ $t('SALES.EDIT') }}
            </button>
            <button
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm text-n-slate-12"
              @click="showActivity = true"
            >
              {{ $t('SALES.ACTIVITY.NEW') }}
            </button>
            <button
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm text-n-slate-12"
              @click="openContact"
            >
              {{ $t('SALES.OPEN_CONTACT') }}
            </button>
            <button
              v-if="opportunity.conversation_id"
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm text-n-slate-12"
              @click="openConversation"
            >
              {{ $t('SALES.OPEN_CONVERSATION') }}
            </button>
            <VoiceCallButton
              :phone="opportunity.contact.phone_number"
              :contact-id="opportunity.contact.id"
              :conversation-id="opportunity.conversation_id"
              :label="$t('SALES.CALL_CONTACT')"
              icon="i-lucide-phone"
              size="sm"
              outline
            />
            <button
              v-if="opportunity.contact.phone_number"
              type="button"
              class="rounded-lg border border-n-weak px-3 py-2 text-sm text-n-slate-12"
              @click="openCallHistory"
            >
              {{ $t('SALES.OPEN_CALL_HISTORY') }}
            </button>
            <button
              type="button"
              class="rounded-lg px-3 py-2 text-sm text-n-ruby-11 hover:bg-n-ruby-3"
              @click="archive"
            >
              {{ $t('SALES.ARCHIVE') }}
            </button>
          </div>
          <section
            class="grid gap-4 rounded-xl border border-n-weak p-4 sm:grid-cols-2"
          >
            <div>
              <p class="text-xs text-n-slate-10">{{ $t('SALES.CLIENT') }}</p>
              <p class="text-sm font-medium text-n-slate-12">
                {{ opportunity.contact.name || opportunity.contact.identifier }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.PHONE') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.contact.phone_number || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.FORM.PRODUCT') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.product_name || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.FORM.VALUE') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.value || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.FORM.OWNER') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.owner?.name }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.FILTERS.CHANNEL') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.source_channel || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">
                {{ $t('SALES.ORIGIN_CONVERSATION') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.conversation_display_id || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10">{{ $t('SALES.FORM.TEAM') }}</p>
              <p class="text-sm text-n-slate-12">
                {{ opportunity.team?.name || '—' }}
              </p>
            </div>
          </section>
          <section class="rounded-xl border border-n-weak p-4">
            <label class="text-sm font-medium text-n-slate-11"
              >{{ $t('SALES.STAGE')
              }}<select
                v-model="selectedStageId"
                class="mt-1 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
              >
                <option
                  v-for="stage in stages"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select></label
            >
            <template v-if="selectedStage?.stage_type === 'lost'">
              <label class="mt-3 block text-sm text-n-slate-11"
                >{{ $t('SALES.LOSS_REASON')
                }}<select
                  v-model="selectedLossReasonId"
                  required
                  class="mt-1 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
                >
                  <option disabled value="">
                    {{ $t('SALES.SELECT_LOSS_REASON') }}
                  </option>
                  <option
                    v-for="reason in lossReasons"
                    :key="reason.id"
                    :value="reason.id"
                  >
                    {{ reason.name }}
                  </option>
                </select></label
              >
              <label class="mt-3 block text-sm text-n-slate-11"
                >{{ $t('SALES.LOSS_NOTES')
                }}<textarea
                  v-model="lossNotes"
                  rows="2"
                  class="mt-1 w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2"
                />
              </label>
            </template>
            <button
              type="button"
              class="mt-3 rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-white"
              :disabled="
                selectedStage?.stage_type === 'lost' && !selectedLossReasonId
              "
              @click="move"
            >
              {{ $t('SALES.UPDATE_STAGE') }}
            </button>
          </section>
          <section>
            <div class="mb-3 flex items-center justify-between">
              <h3 class="font-semibold text-n-slate-12">
                {{ $t('SALES.ACTIVITIES') }}
              </h3>
            </div>
            <SalesActivityForm
              v-if="showActivity"
              :opportunity-id="opportunity.id"
              :activity="editingActivity"
              @close="
                showActivity = false;
                editingActivity = null;
              "
              @saved="activitySaved"
            />
            <div class="mt-3 space-y-2">
              <button
                v-for="activity in opportunity.activities"
                :key="activity.id"
                type="button"
                class="flex w-full items-center gap-3 rounded-lg border border-n-weak p-3 text-left"
                :class="
                  activity.status === 'overdue'
                    ? 'bg-n-ruby-3'
                    : 'bg-n-surface-1'
                "
                @click="updateActivity(activity)"
              >
                <span
                  :class="
                    activity.status === 'overdue'
                      ? 'i-lucide-clock-alert text-n-ruby-11'
                      : 'i-lucide-calendar-clock text-n-slate-10'
                  "
                  class="size-4"
                /><span class="min-w-0 flex-1"
                  ><span
                    class="block truncate text-sm font-medium text-n-slate-12"
                    >{{ activity.title }}</span
                  ><span class="block text-xs text-n-slate-10">
                    {{ new Date(activity.scheduled_at).toLocaleString() }}
                  </span>
                  <span class="block text-xs text-n-slate-10">
                    {{ $t(`SALES.ACTIVITY.STATUSES.${activity.status}`) }}
                  </span></span
                >
              </button>
            </div>
          </section>
          <section>
            <h3 class="mb-3 font-semibold text-n-slate-12">
              {{ $t('SALES.HISTORY') }}
            </h3>
            <ol class="space-y-3 border-l border-n-weak pl-4">
              <li
                v-for="item in opportunity.stage_history"
                :key="item.id"
                class="text-sm text-n-slate-11"
              >
                <p>
                  {{ item.from_stage?.name || $t('SALES.CREATED') }}
                  {{ $t('SALES.MOVED_TO') }}
                  {{ item.to_stage.name }}
                </p>
                <p class="text-xs text-n-slate-10">
                  {{ item.user.name }}
                  {{ new Date(item.changed_at).toLocaleString() }}
                </p>
              </li>
            </ol>
          </section>
        </div>
      </aside>
    </div>
    <SalesOpportunityForm
      v-if="showEdit && opportunity"
      :opportunity="opportunity"
      :contact-id="opportunity.contact.id"
      :conversation-id="opportunity.conversation_id"
      @close="showEdit = false"
      @saved="
        showEdit = false;
        load();
        $emit('changed');
      "
    />
  </Teleport>
</template>
