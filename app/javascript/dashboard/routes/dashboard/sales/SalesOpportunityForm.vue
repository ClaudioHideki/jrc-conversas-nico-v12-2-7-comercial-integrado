<script setup>
import { onMounted, reactive, ref } from 'vue';
import SalesAPI from 'dashboard/api/sales';
import ContactsAPI from 'dashboard/api/contacts';
import { useAlert } from 'dashboard/composables';
import { useRoute, useRouter } from 'vue-router';

const props = defineProps({
  contactId: { type: [Number, String], default: null },
  conversationId: { type: [Number, String], default: null },
  opportunity: { type: Object, default: null },
  targetStageId: { type: [Number, String], default: null },
});

const emit = defineEmits(['close', 'saved']);
const route = useRoute();
const router = useRouter();
const isSaving = ref(false);
const openAfterSave = ref(false);
const contacts = ref([]);
const metadata = ref({ users: [], teams: [] });
const form = reactive({
  contact_id: props.contactId || '',
  conversation_display_id: props.conversationId || '',
  owner_id: props.opportunity?.owner?.id || '',
  team_id: props.opportunity?.team?.id || '',
  title: props.opportunity?.title || '',
  product_name: props.opportunity?.product_name || '',
  value: props.opportunity?.value || '',
  temperature: props.opportunity?.temperature || 'warm',
  notes: props.opportunity?.notes || '',
  idempotency_key: props.opportunity
    ? null
    : window.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`,
});
const nextActivity = reactive({
  activity_type: 'follow_up',
  title: '',
  scheduled_at: '',
  status: 'scheduled',
});

const controlClass =
  'w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand';

const save = async () => {
  isSaving.value = true;
  try {
    const request = props.opportunity
      ? SalesAPI.updateOpportunity(props.opportunity.id, form)
      : SalesAPI.createOpportunity(form);
    const response = await request;
    let { data } = response;
    if (
      !props.opportunity &&
      props.targetStageId &&
      Number(data.stage.id) !== Number(props.targetStageId)
    ) {
      const moveResponse = await SalesAPI.moveOpportunity(data.id, {
        stage_id: props.targetStageId,
      });
      data = moveResponse.data;
    }
    if (
      !props.opportunity &&
      response.status === 201 &&
      nextActivity.title &&
      nextActivity.scheduled_at
    ) {
      await SalesAPI.createActivity(data.id, nextActivity);
    }
    useAlert('Oportunidade salva com sucesso.');
    emit('saved', data);
    if (openAfterSave.value) {
      router.push({
        name: 'sales_pipeline_index',
        params: { accountId: route.params.accountId },
        query: { opportunityId: data.id },
      });
    }
  } catch (error) {
    useAlert(
      error.response?.data?.message ||
        error.response?.data?.error ||
        'Não foi possível salvar a oportunidade.'
    );
  } finally {
    isSaving.value = false;
  }
};

onMounted(async () => {
  const requests = [SalesAPI.metadata()];
  if (!props.contactId) requests.push(ContactsAPI.get(1));
  const [metadataResponse, contactsResponse] = await Promise.all(requests);
  metadata.value = metadataResponse.data;
  contacts.value = contactsResponse?.data?.payload || [];
});
</script>

<template>
  <Teleport to="body">
    <div
      class="fixed inset-0 z-[70] flex justify-end bg-black/40"
      @click.self="$emit('close')"
    >
      <form
        class="flex h-full w-full max-w-lg flex-col bg-n-solid-2 shadow-2xl"
        @submit.prevent="save"
      >
        <header
          class="flex items-center justify-between border-b border-n-weak px-6 py-4"
        >
          <h2 class="text-lg font-semibold text-n-slate-12">
            {{
              opportunity
                ? $t('SALES.FORM.EDIT_TITLE')
                : $t('SALES.FORM.NEW_TITLE')
            }}
          </h2>
          <button
            type="button"
            class="i-lucide-x size-5 text-n-slate-11"
            :aria-label="$t('SALES.CLOSE')"
            @click="$emit('close')"
          />
        </header>
        <div class="flex-1 space-y-4 overflow-y-auto p-6">
          <label
            v-if="!contactId"
            class="block text-sm font-medium text-n-slate-11"
          >
            {{ $t('SALES.FORM.CONTACT') }}
            <select
              v-model="form.contact_id"
              required
              :class="controlClass"
              class="mt-1"
            >
              <option disabled value="">
                {{ $t('SALES.FORM.SELECT_CONTACT') }}
              </option>
              <option
                v-for="contact in contacts"
                :key="contact.id"
                :value="contact.id"
              >
                {{
                  contact.name ||
                  contact.identifier ||
                  contact.email ||
                  contact.phone_number
                }}
              </option>
            </select>
          </label>
          <label class="block text-sm font-medium text-n-slate-11"
            >{{ $t('SALES.FORM.TITLE')
            }}<input
              v-model="form.title"
              required
              :class="controlClass"
              class="mt-1"
          /></label>
          <label class="block text-sm font-medium text-n-slate-11"
            >{{ $t('SALES.FORM.PRODUCT')
            }}<input
              v-model="form.product_name"
              :class="controlClass"
              class="mt-1"
          /></label>
          <label class="block text-sm font-medium text-n-slate-11"
            >{{ $t('SALES.FORM.VALUE')
            }}<input
              v-model="form.value"
              type="number"
              min="0"
              step="0.01"
              :class="controlClass"
              class="mt-1"
          /></label>
          <label class="block text-sm font-medium text-n-slate-11">
            {{ $t('SALES.FORM.TEMPERATURE') }}
            <select
              v-model="form.temperature"
              :class="controlClass"
              class="mt-1"
            >
              <option
                v-for="temperature in ['cold', 'warm', 'hot', 'very_hot']"
                :key="temperature"
                :value="temperature"
              >
                {{ $t(`SALES.TEMPERATURES.${temperature}`) }}
              </option>
            </select>
          </label>
          <fieldset
            v-if="!opportunity"
            class="space-y-3 rounded-xl border border-n-weak p-4"
          >
            <legend class="px-1 text-sm font-medium text-n-slate-11">
              {{ $t('SALES.FORM.NEXT_ACTIVITY') }}
            </legend>
            <select v-model="nextActivity.activity_type" :class="controlClass">
              <option
                v-for="type in [
                  'call',
                  'meeting',
                  'follow_up',
                  'task',
                  'demonstration',
                ]"
                :key="type"
                :value="type"
              >
                {{ $t(`SALES.ACTIVITY.TYPES.${type}`) }}
              </option>
            </select>
            <input
              v-model="nextActivity.title"
              :class="controlClass"
              :placeholder="$t('SALES.ACTIVITY.TITLE')"
            />
            <input
              v-model="nextActivity.scheduled_at"
              type="datetime-local"
              :class="controlClass"
              :aria-label="$t('SALES.ACTIVITY.WHEN')"
            />
          </fieldset>
          <label
            v-if="metadata.users.length > 1"
            class="block text-sm font-medium text-n-slate-11"
          >
            {{ $t('SALES.FORM.OWNER') }}
            <select v-model="form.owner_id" :class="controlClass" class="mt-1">
              <option value="">{{ $t('SALES.FORM.CURRENT_USER') }}</option>
              <option
                v-for="user in metadata.users"
                :key="user.id"
                :value="user.id"
              >
                {{ user.name }}
              </option>
            </select>
          </label>
          <label
            v-if="metadata.teams.length"
            class="block text-sm font-medium text-n-slate-11"
          >
            {{ $t('SALES.FORM.TEAM') }}
            <select v-model="form.team_id" :class="controlClass" class="mt-1">
              <option value="">{{ $t('SALES.FORM.NO_TEAM') }}</option>
              <option
                v-for="team in metadata.teams"
                :key="team.id"
                :value="team.id"
              >
                {{ team.name }}
              </option>
            </select>
          </label>
          <label class="block text-sm font-medium text-n-slate-11"
            >{{ $t('SALES.FORM.NOTES')
            }}<textarea
              v-model="form.notes"
              rows="5"
              :class="controlClass"
              class="mt-1"
            />
          </label>
        </div>
        <footer class="flex justify-end gap-2 border-t border-n-weak px-6 py-4">
          <button
            type="button"
            class="rounded-lg px-4 py-2 text-sm text-n-slate-11 hover:bg-n-alpha-2"
            @click="$emit('close')"
          >
            {{ $t('SALES.CANCEL') }}
          </button>
          <button
            type="submit"
            :disabled="isSaving"
            class="rounded-lg bg-n-brand px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
          >
            {{ isSaving ? $t('SALES.SAVING') : $t('SALES.SAVE') }}
          </button>
          <button
            v-if="!opportunity"
            type="submit"
            :disabled="isSaving"
            class="rounded-lg border border-n-brand px-4 py-2 text-sm font-medium text-n-blue-11 disabled:opacity-50"
            @click="openAfterSave = true"
          >
            {{ $t('SALES.FORM.SAVE_AND_OPEN') }}
          </button>
        </footer>
      </form>
    </div>
  </Teleport>
</template>
