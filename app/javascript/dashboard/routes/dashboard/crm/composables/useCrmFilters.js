import { reactive } from 'vue';

export function useCrmFilters(initialFilters = {}) {
  const filters = reactive({
    ...initialFilters,
  });

  const setFilter = (key, value) => {
    filters[key] = value;
  };

  const clearFilters = (defaultFilters = {}) => {
    Object.keys(filters).forEach(key => {
      delete filters[key];
    });
    Object.assign(filters, defaultFilters);
  };

  return {
    filters,
    setFilter,
    clearFilters,
  };
}
