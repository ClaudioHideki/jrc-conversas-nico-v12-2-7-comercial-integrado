<script setup>
import { reactive, ref } from 'vue';
import SalesAPI from 'dashboard/api/sales';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  opportunityId: { type: [Number, String], required: true },
  activity: { type: Object, default: null },
});
const emit = defineEmits(['close', 'saved']);
const saving = ref(false);
const form = reactive({
  activity_type: props.activity?.activity_type || 'follow_up',
  title: props.activity?.title || '',
  scheduled_at: props.activity?.scheduled_at?.slice(0, 16) || '',
  status: props.activity?.stored_status || 'scheduled',
  notes: props.activity?.notes || '',
});
const controlClass =
  'w-full rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12 outline-none focus:border-n-brand';

const save = async () => {
  saving.value = true;
  try {
    const request = props.activity
      ? SalesAPI.updateActivity(props.activity.id, form)
      : SalesAPI.createActivity(props.opportunityId, form);
    await request;
    emit('saved');
  } catch (error) {
    useAlert(
      error.response?.data?.message || 'Não foi possível salvar a atividade.'
    );
  } finally {
    saving.value = false;
  }
};
</script>

<template>
  <!-- eslint-disable vue/max-attributes-per-line -->
  <form
    class="space-y-4 rounded-xl border border-n-weak bg-n-surface-1 p-4"
    @submit.prevent="save"
  >
    <div class="flex items-center justify-between">
      <h3 class="font-semibold text-n-slate-12">
        {{ activity ? $t('SALES.ACTIVITY.EDIT') : $t('SALES.ACTIVITY.NEW') }}
      </h3>
      <button
        type="button"
        class="i-lucide-x size-4 text-n-slate-11"
        :aria-label="$t('SALES.CLOSE')"
        @click="$emit('close')"
      />
    </div>
    <label class="block text-sm text-n-slate-11"
      >{{ $t('SALES.ACTIVITY.TYPE')
      }}<select v-model="form.activity_type" :class="controlClass" class="mt-1">
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
      </select></label
    >
    <label class="block text-sm text-n-slate-11"
      >{{ $t('SALES.ACTIVITY.TITLE')
      }}<input v-model="form.title" required :class="controlClass" class="mt-1"
    /></label>
    <label class="block text-sm text-n-slate-11"
      >{{ $t('SALES.ACTIVITY.WHEN')
      }}<input
        v-model="form.scheduled_at"
        required
        type="datetime-local"
        :class="controlClass"
        class="mt-1"
    /></label>
    <label v-if="activity" class="block text-sm text-n-slate-11"
      >{{ $t('SALES.ACTIVITY.STATUS')
      }}<select v-model="form.status" :class="controlClass" class="mt-1">
        <option
          v-for="status in ['scheduled', 'completed', 'cancelled']"
          :key="status"
          :value="status"
        >
          {{ $t(`SALES.ACTIVITY.STATUSES.${status}`) }}
        </option>
      </select></label
    >
    <label class="block text-sm text-n-slate-11"
      >{{ $t('SALES.ACTIVITY.NOTES')
      }}<textarea
        v-model="form.notes"
        rows="3"
        :class="controlClass"
        class="mt-1"
      />
    </label>
    <div class="flex justify-end gap-2">
      <button
        type="button"
        class="rounded-lg px-3 py-2 text-sm text-n-slate-11"
        @click="$emit('close')"
      >
        {{ $t('SALES.CANCEL') }}</button
      ><button
        type="submit"
        :disabled="saving"
        class="rounded-lg bg-n-brand px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {{ $t('SALES.SAVE') }}
      </button>
    </div>
  </form>
</template>
