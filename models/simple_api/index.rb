module SimpleApi
  class Index
    class << self
      def breadcrumbs(sphere, param, params)
        lded = json_load(params['p'], params['p'])
        lded ||= {}
        hash = {}
        # range = lded['offset']..(lded['offset'] + range.last - range.first) if lded['offset']
        # range = range.first..(lded['limit'] - 1 + range.first) if lded['limit']
        # sphere = root.sphere
        # route = SimpleApiRouter.new('en', sphere)
        hash.merge!('criteria' => lded.delete('criteria')) if lded.has_key?('criteria')
        hash.merge!(lded["filters"]) if lded.has_key?('filters')
        route = SimpleApiRouter.new(:en, sphere)
        rules = SimpleApi::Rule.where(sphere: sphere, param: param).all
        rat = SimpleApi::Sitemap::Reference.where(duplicate_id: nil, is_empty: false, url: route.route_to('rating', {}))
        return JSON.dump({breadcrumbs: nil}) if params.blank? || params[:p].blank?

      end

      def roots(sphere, param)
        root = SimpleApi::Sitemap::Root.reverse_order(:id).where(sphere: sphere).first
        # refactor for range limiting
        JSON.dump(
          {
          next: SimpleApi::Rule.where(sphere: sphere, param: param).where('traversal_order is not null').order(:position).all.select{|r| json_load(r.traversal_order, []).present? }.map do |r|
            content = json_load(r.content, {})
            {
              name: r.name,
              label: (content['index'] || content['h1'] || r.name),
              url:"/en/#{sphere}/index/#{param.to_s},#{r.name}",
              links: r.objects_dataset.where(index_id: nil).all.map{|o| {name: o.label, url: o.url, photo: o.photo} }.uniq.sample(4).shuffle
            }
          end
          }.tap{|x| x[:total] = x[:next].size }
        )
      end

      def tree(sphere, rule_selector, rule_params, params)
        root = SimpleApi::Sitemap::Root.reverse_order(:id).where(sphere: sphere).first
        selector = rule_selector.strip.split(',')
        rat = selector.shift
        # return roots(sphere) unless 'rating' == rat
        if selector.empty?
          return roots(sphere, rat)
        end
        lang = "en"
        name = selector.shift
        return roots(sphere, rat) unless name.present?
        return roots(sphere, rat) unless rule = SimpleApi::Rule.where(name: name, param: rat).first
        fields = selector || []
        leaf_page(root, rule, name, selector, params, rat)
       end


      def index_links(bcr, curr, route, param)
        sel = bcr # + [{item[:filter] => item[:value]}]
        # index_ids = SimpleApi::Sitemap::Index.where(parent_id: curr[:id]).all.map(&:pk)
        if curr[:id]
        links = SimpleApi::Sitemap::Reference.where(super_index_id: curr[:id], is_empty: false).all
        else
        links = SimpleApi::Sitemap::Reference.where(index_id: curr[:id], is_empty: false).all
        end
        rul = SimpleApi::Rule[curr[:rule_id]]
        url = route.route_to(param, sel.inject({}){|r, h| r.merge(h) })
        if links.present?
          links.map do |ref|
            lbl = tr_h1_params(json_load(ref.rule.content, {})['h1'], json_load(ref.json, {}))
            photo = ref.index.objects.sample.try(:photo)
            next unless photo
            {
              label: lbl,
              photo: photo,
              url: ref[:url]
            }
          end
        else
          []
        end
      end

      def leaf_page(root, rule, name, selector, params, param)
        range = 0..99
        parent = nil
        lded = json_load(params['p'], params['p'])
        lded ||= {}
        hash = {}
        range = lded['offset']..(lded['offset'] + range.last - range.first) if lded['offset']
        range = range.first..(lded['limit'] - 1 + range.first) if lded['limit']
        sphere = root.sphere
        route = SimpleApiRouter.new('en', sphere)
        hash.merge!('criteria' => lded.delete('criteria')) if lded.has_key?('criteria')
        hash.merge!(lded["filters"]) if lded.has_key?('filters')
        curr = {id: nil, rule_id: rule.pk}
        p curr, hash

        bcr = []
        cselector = selector.dup
        p 'cselector', cselector
        loop do
          break if cselector.blank?
          fname = cselector.shift
          parent = curr
          flt = SimpleApi::RuleDefs.from_name(fname).load_rule(fname, hash[fname])
          p 'flt-val', fname, hash[fname]
          curr = rule.indexes_dataset.where(root_id: root.pk, parent_id: parent[:id], filter: fname, value: flt.convolution(hash[fname]).to_s).first
          unless curr
            if cselector.present?
              puts "skipable #{fname}-#{hash[fname]}"
              pfname = [fname]
              pval = [flt.convolution(hash[fname])]
              cname = []
              cval = []
              cselector.each do |nm|
                cname << nm
                f = SimpleApi::RuleDefs.from_name(nm).load_rule(nm, hash[nm])
                cval << f.convolution(hash[nm])
                curr = rule.indexes_dataset.where(root_id: root.pk, parent_id: parent[:id], filter: JSON.dump(pfname + cname), value: JSON.dump(pval + cval)).first
                break if curr
              end
              cselector.shift(cname.size) if curr
            end
            break unless curr
          end
          bcr << {json_load(curr.filter,curr.filter) => json_load(curr.value, curr.value)}
        end
        p 'uncurr', curr
        p 'bcr', bcr
        unless curr
          return JSON.dump({'ratings' => index_links(bcr, parent, route, 'rating')})
        end
        nxt = rule.indexes_dataset.where(root_id: root.pk, parent_id: curr[:id]).all.select{|n| next_links(n).present? }
        p 'nxt', nxt
        rsp = {}
        if nxt.present?
          rsp['next'] = nxt[range].map do |item|
            sel = bcr + [{json_load(item.filter, item.filter) => json_load(item.value, item.value)}].map do |i|
              if i.keys.first.is_a? ::Array
                i.keys.first.zip(i.values.first)
              else
                i
              end
            end.flatten.tap{|x| p 'sm', x }.each_slice(2){|a, b| Hash[a, b] }.tap{|x| p 'selmap', x }
            spath = sel.map{|i| i.keys.first }.join(',')
            p 'sel', sel
            parm = route.route_to("index/#{[rule.param, name, sel.blank? ? nil : sel.map{|i| i.keys.first }].compact.join(',')}", sel.inject({}){|r, i| r.merge(i) })
            {
              'label' => "#{item.filter}:#{item.value}",
              'name' => item.filter,
              'url' => parm,
              'links' => next_links(item)
            }
          end
          rsp['total'] = nxt.size
        end
        rsp['ratings'] = index_links(bcr, curr, route, 'rating')
        # if rsp['ratings'].present?
        #   rsp.delete('next')
        #   rsp.delete('total')
        # end
        # rsp['ratings_total'] = SimpleApi::Sitemap::Reference.where(index_id: curr[:id], is_empty: false, duplicate_id: nil).count
        JSON.dump(rsp)
      end

      def next_links(index)
        p 'nl-idx', index
        index.objects.sample(4).map do |lnk|
          {
            'name' => lnk.label,
            'url' => lnk.url,
            'photo' => lnk.photo
          }
        end.tap{|x| p 'nl-rslt', x }
      end

      # def mk_params(sel)
      #   slctr = sel.dup
      #   # opts = p.dup
      #   # flts = p["filter"] || {}
      #   crit = slctr.select do |hash|
      #     hash.keys.include? 'criteria'
      #   end
      #   slctr.delete_if do |hash|
      #     hash.keys.include? 'criteria'
      #   end
      #   slctr.sort_by{|i| i.keys.first }
      #   data = []
      #   list = []
      #   list << 'criteria' unless crit.blank?
      #   data << 'criteria' unless crit.blank?
      #   data << crit.first.values.first if crit.present? && crit.first.values.first.present?
      #   data << 'filters' if slctr.present? && slctr.detect{|h| h.values.first.present? }
      #   slctr.each do |hsh|
      #     list << hsh.keys.first
      #     data << hsh.keys.first if hsh.values.first.present?
      #     data << hsh.values.first if hsh.values.first.present?
      #   end
      #   {list: list, path: data}
      # end

    end
  end
end
