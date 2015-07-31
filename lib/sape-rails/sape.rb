require 'net/http'
require 'fileutils'

class Sape::Processor

  @@default_options = {
    :force_show_code => false,
    :debug => false,
    :show_counter_separately => false,
    :charset => 'UTF-8',
    :servers => ['dispenser-01.saperu.net', 'dispenser-02.saperu.net'],
    :filename => 'links.db',
    :timeout => 3600             # use nil if you don't want to get updates
                                 # In this case, you have to call update()
                                 # manually
  }

  attr_reader :options

  def initialize(user, request, opts)
    @options = @@default_options.merge(opts)

    @user = user
    
    @options[:uri] ||= request.fullpath if request
    @options[:uri_alt] = @options[:uri][-1, 1] == '/' ? @options[:uri][0..-2] : (@options[:uri] + '/')
    
    @remote_ip = request ? request.remote_ip : '127.0.0.1'

    @host = options[:host] || request.host
    @host.gsub!(/^https?:\/\//,'')
    @host.gsub!(/^www\./,'')
    
    if request && request.cookies['sape_cookie'] == @user
      @is_sape_bot = true
      @debug = request.cookies['sape_debug'].to_s == '1'
      @force_update_db = request.cookies['sape_updatedb'].to_s == '1'
    end 
    
    @verbose = options[:verbose] || @debug
    @charset = options[:charset]
    @show_counter_separately = options[:show_counter_separately]
    
    set_data
  end

  def return_links(count = nil, opts = {})
    return @sape_error if @sape_error

    as_block = @show_only_block || opts[:as_block] 
    return return_block_links(count, opts) if as_block && @block_tpl

    html = nil
    if @links_page.is_a?(Array)

      count ||= @links_page.size
      count = @links_page.size if count > @links_page.size
      
      html = @links_page.shift(count).join(@links_delimiter)
      html = "<sape_noindex>#{html}</sape_noindex>" if @is_sape_bot  
    else
      html = @links_page.to_s
      html += "<sape_noindex></sape_noindex>" if @is_sape_bot
    end

    return_html(html)
  end

  def return_block_links(count = nil, opts = {})

    opts = @block_tpl_options.merge(opts) if @block_tpl_options.is_a?(Hash)
    opts.default_proc = proc { |h, k| h.key?(k.to_s) ? h[k.to_s] : (h.key?(k.to_s.to_sym) ? h[k.to_s.to_sym] : nil)} 
    
    block_orientation = opts.delete(:block_orientation) || 1

    return return_html(@links_page.to_s + return_array_links_html('', :is_block_links => true)) unless @links_page.is_a?(Array)
    return return_html('') unless @block_tpl

    need_show_obligatory_block = !@block_ins_itemobligatory.nil?
    count_requested = 0

    need_show_conditional_block = false
    if count && count >= @links_page.size
      count_requested = count
      need_show_conditional_block = !@block_ins_itemconditional.nil?
    end

    count = @links_page.size if count.nil? || count > @links_page.size
    
    links = @links_page.shift(count)
    
    # Подсчет числа опциональных блоков
    nof_conditional = (need_show_obligatory_block && count_requested > links.size) ? count_requested - links.size : 0
    
    if links.empty? && !need_show_obligatory_block
      html = return_array_links_html('', :is_block_links => true, 
                                  :nof_links_requested => count_requested,
                                  :nof_links_displayed => 0,
                                  :nof_obligatory => 0,
                                  :nof_conditional => 0)
      return return_html(html)
    end 
    
    html = ''
    
    # Делаем вывод стилей, только один раз. Или не выводим их вообще, если так задано в параметрах
    if !@block_css_shown && !opts.delete(:block_no_css)
      html += @block_tpl['css'].to_s
      @block_css_shown = true
    end

    # Вставной блок в начале всех блоков
    if @block_ins_beforeall && !@block_ins_beforeall_shown
      html += @block_ins_beforeall
      @block_ins_beforeall_shown = true
    end

    block_tpl_parts = @block_tpl[block_orientation]

    block_tpl = block_tpl_parts['block']
    item_tpl = block_tpl_parts['item']
    item_container_tpl = block_tpl_parts['item_container']
    item_tpl_full = item_container_tpl.gsub('{item}', item_tpl)
    
    nof_items_total = links.size
    
    items = links.map do |link|
      # Обычная красивая ссылка
      link =~ /<a href="(https?:\/\/([^"\/]+)[^"]*)"[^>]*>[\s]*([^<]+)<\/a>/i ||
      # Картиночкая красивая ссылка
      link =~ /<a href="(https?:\/\/([^"\/]+)[^"]*)"[^>]*><img.*?alt="(.*?)".*?><\/a>/i
      
      header = $3.to_s
      header = (header.respond_to?(:mb_chars) ? header.mb_chars : header).capitalize.force_encoding(@charset)
      lnk = $1
      # Если есть раскодированный URL, то заменить его при выводе
      url = (@block_uri_idna && @block_uri_idna[$2.to_i]) ? @block_uri_idna[$2.to_i] : $2  

      item_tpl_full.
        gsub('{header}', header).
        gsub('{text}', link.force_encoding(@charset)).
        gsub('{url}', url).
        gsub('{link}', lnk)
      
    end.join('')
    
    # Вставной обязатльный элемент в блоке
    if need_show_obligatory_block
      items << item_container_tpl.gsub('{item}', @block_ins_itemobligatory.to_s)
      nof_items_total += 1
    end
    
    # Вставные опциональные элементы в блоке
    if need_show_conditional_block && nof_conditional > 0
      items << item_container_tpl.gsub('{item}', @block_ins_itemconditional.to_s) * nof_conditional
      nof_items_total += nof_conditional 
    end
    
    if items != ''
      html << block_tpl.gsub('{items}', items)
      
      # Проставляем ширину, чтобы везде одинковая была
      html.gsub!('{td_width}', (nof_items_total == 0 ? 0 : 100 / nof_items_total).to_s)
      
      # Если задано, то переопределить ширину блока
      html.gsub!('{block_style_custom}', "style=\"width: #{opts[:block_width]} !important;\"") if opts.delete(:block_width)
    end
    
    # Вставной блок в конце блока
    html << @block_ins_afterblock if @block_ins_afterblock
    
    # Заполняем оставшиеся модификаторы значениями
    opts.each { |k,v| html.gsub!("{#{k}}", v.to_s) }
    
    # Очищаем незаполненные модификаторы
    html.gsub!(/\{[a-z\d_\-]+\}/, '')
    
    return_html(return_array_links_html(html, {
      :is_block_links      => true,
      :nof_links_requested => count_requested,
      :nof_links_displayed => count,
      :nof_obligatory      => need_show_obligatory_block ? 1 : 0,
      :nof_conditional     => nof_conditional
    }))
  end

  def return_counter
    # если show_counter_separately = false и выполнен вызов этого метода,
    # то заблокировать вывод js-кода вместе с контентом
    @show_counter_separately = true
    return_obligatory_page_content  
  end

  # update the links database
  def update

    FileUtils.touch(self.options[:filename])
    begin
      self.options[:servers].each do |server|
        content = fetch("http://#{server}/code.php?"\
                             "user=#{@user}&"\
                             "host=#{@host}&"\
                             "charset=#{@charset}") rescue nil
        next if content.nil? || content[0,12] == 'FATAL ERROR:'

        parse_links(content)
        raise "no '__sape_new_url__' in links text" unless @links['__sape_new_url__']

        File.open(@options[:filename], 'w') { |f| f.write content }

        return @links
      end
    rescue
      nil
    end
  end

  private

  def fetch(uri_str, limit = 10)
    return nil if limit == 0
    begin
      url = URI.parse(uri_str)
      request = Net::HTTP::Get.new(url.request_uri)
      # Set user agent to mimick PHP client to get block links
      request['User-Agent'] = 'SAPE_Client PHP 1.2.7' 
      request['Accept-Charset'] = @charset
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true if url.port == 443
      response =  http.request(request)
      case response
      when Net::HTTPSuccess     then response
      when Net::HTTPRedirection, Net::HTTPFound then return get(response['location'], limit - 1)
      else
        response.error!
      end
      response.body.force_encoding(@charset)
    rescue
      return fetch(uri_str, limit - 1)
    end
  end

  # load links from cache and update them if needed
  def fetch_links
    if @options[:timeout]
      stat = File.stat(@options[:filename]) rescue nil
      return update if !stat || stat.mtime < Time.now - @options[:timeout] || stat.size == 0 || @force_update_db
    end

    parse_links(File.read(@options[:filename]))
  end

  def parse_links(content)
    @links = PHP.unserialize(content) || {}
  end
  
  def set_data
    fetch_links
    
    @links_delimiter = @links['__sape_delimiter__']
    @show_only_block = @links['__sape_show_only_block__']
    @block_tpl = @links['__sape_block_tpl__']
    @block_tpl_options = @links['__sape_block_tpl_options__']
    @block_uri_idna = @links['__sape_block_uri_idna__']
    
    [:beforeall, :beforeblock, :afterblock, :itemobligatory, :itemconditional, :afterall].each do |block_name|
      self.instance_variable_set "@block_ins_#{block_name}", @links["__sape_block_ins_#{block_name}__"]
    end

    @links_page = @links[@options[:uri]] || @links[@options[:uri_alt]]
    @links_page ||= @links['__sape_new_url__'] if @options[:force_show_code] || @is_sape_bot
    @links_page ||= []
  end

  def return_obligatory_page_content
    return '' if @page_obligatory_output_shown
    
    @page_obligatory_output_shown = true
    @links['__sape_page_obligatory_output__'].to_s
  end
  
  def return_html(html)
    html = return_obligatory_page_content + html unless @show_counter_separately
#TODO debug output
    html
  end
  
  def return_array_links_html(html, opts = {})
#TODO iconv
    if @is_sape_bot
      html = "<sape_noindex>#{html}</sape_noindex>"
      if opts[:is_block_links]
        opts[:nof_links_requested] ||= 0
        opts[:nof_links_displayed] ||= 0
        opts[:nof_obligatory] ||= 0
        opts[:nof_conditional] ||= 0
      
        html = "<sape_block nof_req=\"#{opts[:nof_links_requested]}\""\
                    " nof_displ=\"#{opts[:nof_links_displayed]}\""\
                    " nof_oblig=\"#{opts[:nof_obligatory]}\""\
                    " nof_cond=\"#{opts[:nof_conditional]}\""\
                    ">#{html}</sape_block>"
      end
    end     

    html
  end

end
