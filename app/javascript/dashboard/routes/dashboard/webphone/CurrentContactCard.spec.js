import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import CurrentContactCard from './CurrentContactCard.vue';

const contact = {
  id: 42,
  name: 'Contato JRC',
  phone_number: '+55 11 95298-5670',
};

const mountCard = props =>
  mount(CurrentContactCard, {
    props: {
      accountId: 1,
      searchResults: [contact],
      ...props,
    },
    global: {
      stubs: {
        Avatar: true,
        RouterLink: true,
      },
    },
  });

describe('CurrentContactCard', () => {
  it('keeps contact selection separate from the dial action', async () => {
    const wrapper = mountCard();

    await wrapper.find('button.flex-1').trigger('click');
    expect(wrapper.emitted('selectContact')?.[0]).toEqual([contact]);
    expect(wrapper.emitted('dialContact')).toBeUndefined();

    await wrapper.find('button[title^="Ligar:"]').trigger('click');
    expect(wrapper.emitted('dialContact')?.[0]).toEqual([contact]);
  });

  it('requests the next page without replacing the current list', async () => {
    const wrapper = mountCard({ hasMore: true, searchResults: [] });

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('Carregar mais'))
      .trigger('click');

    expect(wrapper.emitted('loadMore')).toHaveLength(1);
  });
});
