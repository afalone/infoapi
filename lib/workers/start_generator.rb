class StartGenerator
  include Sidekiq::Worker
  def perform(spheres, session_id = nil)
    slist = spheres.split(' ')
    sitemap_session = SimpleApi::Sitemap::SitemapSession[session_id]
    sitemap_session ||= SimpleApi::Sitemap::SitemapSession.where(state: 'started').reverse_order(:created_at).all.select{|s| json_load(s.params, {})['spheres'].try(:sort) == slist.sort }.first
    unless sitemap_session
      sitemap_session = SimpleApi::Sitemap::SitemapSession.create(created_at: Time.now, state: 'started', updated_at: Time.now, params: JSON.dump({'spheres' => slist}))
    end
    prod = SimpleApi::Sitemap::Production.create(sitemap_session_id: sitemap_session.pk, step_params: JSON.dump({spheres: slist}))
    prod.start
  end
end
