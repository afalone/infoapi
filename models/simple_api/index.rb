module SimpleApi
  class Index
    class << self
      def breadcrumbs(sphere, param, params)
        lded = json_load(params['p'], params['p'])
        lded ||= {}
        hash = {}
        hash.merge!('criteria' => lded.delete('criteria')) if lded.has_key?('criteria')
        hash.merge!(lded.delete("filters")) if lded.has_key?('filters')
        route = SimpleApiRouter.new(:en, sphere)
        rules = SimpleApi::Rule.where(sphere: sphere, param: param).order(%i(position id)).all
        rat = SimpleApi::Sitemap::Reference.where(is_empty: false, rule_id: rules.map(&:pk), url: route.route_to('rating', hash.dup)).first
        return JSON.dump({breadcrumbs: nil}) unless rat
        idx = rat.index
        # idx = rat.super_index || rat.index
        JSON.dump({breadcrumbs: idx.try(:breadcrumbs)})
      end

      def rules(sphere, param, rule, rng, r_rng)
        root = SimpleApi::Sitemap::Root.reverse_order(:id).where(sphere: sphere).first
        nxt = rule.indexes_dataset.where(parent_id: nil, root_id: root.pk).offset(rng.first).limit(rng.size).all
        # refactor for range limiting
        route = SimpleApiRouter.new('en', sphere)
        rtngs = index_links(nil, route, 'rating', rule, r_rng)
        rsp = {
          breadcrumbs: rule.breadcrumbs,
          # next: SimpleApi::Rule.where(sphere: sphere, param: param).where('traversal_order is not null').order(:position).all.select{|r| json_load(r.traversal_order, []).present? }.map do |r|
          next: nxt.map do |r|
            # content = json_load(r.content, {})
            {
              name: r.filter,
              label: r.label,  #(content['index'] || content['h1'] || r.name),
              url: r.url, #"/en/#{sphere}/index/#{param.to_s},#{r.name}",
              links: next_links(r)
              # links: r.objects_dataset.where(index_id: r.pk).all.map{|o| {name: o.label, url: o.url, photo: o.photo} }.uniq.sample(4).shuffle
            }
          end
        }.tap{|x| x[:total] = x[:next].size }
        rsp['ratings'] = rtngs #[r_range]
        rsp.delete('ratings') unless rsp['ratings'].present?
        if rsp['ratings'].present?
          rsp.delete(:next)
          rsp.delete(:total)
          rsp[:total_ratings] = rtngs.size
        end
        JSON.dump(rsp)

      end

      def roots(sphere, param)
        root = SimpleApi::Sitemap::Root.reverse_order(:id).where(sphere: sphere).first
        # refactor for range limiting
        JSON.dump(
          {
            breadcrumbs: root.breadcrumbs,
            next: SimpleApi::Sitemap::Index.where(root_id: root.pk, parent_id: nil).map do |idx|
              {
                label: idx.label,
                url: idx.url,
                links: next_links(idx)
              }
            end,
            total: SimpleApi::Sitemap::Index.where(root_id: root.pk, parent_id: nil).count
          } #.tap{|x| x[:total] = x[:next].size }
        )
      end

      def tree(sphere, rule_selector, rule_params, params)
        range = 0..99
        r_range = 0..99
        lded = json_load(params['p'], {})
        # lded ||= {}
        hash = {}
        range = lded['offset']..(lded['offset'] + range.last - range.first) if lded['offset']
        range = range.first..(lded['limit'] - 1 + range.first) if lded['limit']
        r_range = lded['offset_ratings']..(lded['offset_ratings'] + r_range.last - r_range.first) if lded['offset_ratings']
        r_range = r_range.first..(lded['limit_ratings'] - 1 + r_range.first) if lded['limit_ratings']
        root = SimpleApi::Sitemap::Root.reverse_order(:id).where(sphere: sphere).first
        selector = rule_selector.strip.split(',')
        rat = selector.shift
        # return roots(sphere) unless 'rating' == rat
        if selector.empty?
          return roots(sphere, rat)
        end
        lang = "en"
        name = selector.shift
        rule = SimpleApi::Rule.where(name: name, param: rat, sphere: sphere).first
        fields = selector || []
        leaf_page(root, rule, name, selector, params, rat)
      end


      def index_links(curr, route, param, rule, range)
        if curr && curr.children_dataset.count > 0
          cnt = SimpleApi::Sitemap::ObjectData.select(:object_data_items__id, :object_data_items__index_id, Sequel.function(:random).as(:random), :object_data_items__photo, :refs__url, :refs__rule_id, :refs__json).distinct(:object_data_items__index_id).join(:indexes, indexes__id: :object_data_items__index_id).join(:refs, indexes__id: :refs__index_id).where(refs__is_empty: false, refs__index_id: curr.try(:pk)).count
          chld = SimpleApi::Sitemap::ObjectData.select(:object_data_items__id, :object_data_items__label, :object_data_items__index_id, Sequel.function(:random).as(:random), :object_data_items__photo, :refs__url, :refs__rule_id, :refs__json).distinct(:object_data_items__index_id).join(:indexes, indexes__id: :object_data_items__index_id).join(:refs, indexes__id: :refs__index_id).where(refs__is_empty: false, refs__index_id: curr.try(:pk)).offset(range.first).limit(range.size).all
        else
          cnt = 0
          chld = []
        end
        if chld.empty? && curr
          return curr.references_dataset.count, curr.references_dataset.offset(range.first).limit(range.size).all.map do |ref|
            {
              label: ref.label,
              photo: ref.crypto_hash ? "/api/v1/picture?hash=#{ref.crypto_hash}" : nil,
              # photo: ref.crypto_hash ? "/api/v1/picture?hash=#{ref.crypto_hash}" : ref.photo,
              url: ref.url
            }
          end
        end
        chld.map do |ref|
          {
            label: ref.label,
            photo: ref.crypto_hash ? "/api/v1/picture?hash=#{ref.crypto_hash}" : nil,
            url: ref.url
          }
        end
      end

      def leaf_page(root, rule, name, selector, params, param)
        range = 0..99
        r_range = 0..99
        parent = nil
        lded = json_load(params['p'])
        # lded = json_load(params['p'], params['p'])
        lded ||= {}
        hash = {}
        range = lded['offset']..(lded['offset'] + range.last - range.first) if lded['offset']
        range = range.first..(lded['limit'] - 1 + range.first) if lded['limit']
        r_range = lded['offset_ratings']..(lded['offset_ratings'] + r_range.last - r_range.first) if lded['offset_ratings']
        r_range = r_range.first..(lded['limit_ratings'] - 1 + r_range.first) if lded['limit_ratings']
        sphere = root.sphere
        route = SimpleApiRouter.new('en', sphere)
        hash.merge!('criteria' => lded.delete('criteria')) if lded.has_key?('criteria')
        hash.merge!(lded["filters"]) if lded.has_key?('filters')
        hash.delete_if{|k, v| !selector.include?(k) }
        hash.merge!('catalog' => hash.delete("path")) if hash.has_key?('path')
        # curr = {id: nil, rule_id: rule.pk}

        ccr = route.route_to((["index/#{param}", rule.name] + selector).join(','), hash)
        curr = SimpleApi::Sitemap::Index.where(url: ccr).first
        rsp = {}
        return '{}' unless curr
        # return rules(sphere, root.param, rule, range, r_range) unless curr
        nxt_size = curr.children_dataset.select(:indexes__id).join(:object_data_items, index_id: :id).distinct(:indexes__id).count
        nxt = curr.children_dataset.select(:indexes__id).join(:object_data_items, index_id: :id).distinct(:indexes__id).offset(range.first).limit(range.size).map(&:reload)
        if nxt.present?
          rsp['next'] = nxt.map do |item|
            {
              'label' => item.label,
              'name' => item.filter,
              'url' => item.url,
              'links' => next_links(item)
            }
          end
          rsp['total'] = nxt_size
        end
        r_cnt, rtngs = index_links(curr, route, 'rating', curr.rule, r_range)
        rsp['ratings'] = rtngs #[r_range]
        rsp.delete('ratings') unless rsp['ratings'].present?
        if rsp['ratings'].present?
          rsp.delete('next')
          rsp.delete('total')
          rsp['total_ratings'] = r_cnt
        end
        rsp['breadcrumbs'] = curr.try(:breadcrumbs)
        JSON.dump(rsp)
      end

      def next_links(index)
        index.objects_dataset.order{Sequel.function(:random)}.limit(4).all.map do |lnk|
          {
            'name' => lnk.label,
            'url' => lnk.url,
            'photo' => lnk.photo
          }
        end
      end
    end
  end
end
