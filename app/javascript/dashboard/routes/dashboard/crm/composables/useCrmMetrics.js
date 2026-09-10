export function useCrmMetrics() {
  const formatBRL = cents => {
    if (cents === null || cents === undefined) return 'R$ 0,00';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL',
      minimumFractionDigits: 2,
    }).format(cents / 100);
  };

  const formatPercent = val => {
    if (val === null || val === undefined) return '0%';
    return new Intl.NumberFormat('pt-BR', {
      style: 'percent',
      minimumFractionDigits: 1,
    }).format(val / 100);
  };

  const formatCount = val => {
    if (val === null || val === undefined) return '0';
    return new Intl.NumberFormat('pt-BR').format(val);
  };

  return {
    formatBRL,
    formatPercent,
    formatCount,
  };
}
