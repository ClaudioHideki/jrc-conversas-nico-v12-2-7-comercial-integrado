import { ref, computed } from 'vue';

export function useCrmPagination(initialPage = 1, initialPerPage = 20) {
  const page = ref(initialPage);
  const perPage = ref(initialPerPage);
  const totalCount = ref(0);

  const hasMore = computed(() => {
    return page.value * perPage.value < totalCount.value;
  });

  const loadMore = () => {
    if (hasMore.value) {
      page.value += 1;
    }
  };

  const resetPagination = () => {
    page.value = 1;
    totalCount.value = 0;
  };

  return {
    page,
    perPage,
    totalCount,
    hasMore,
    loadMore,
    resetPagination,
  };
}
