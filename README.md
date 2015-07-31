# sape-rails

Вывод ссылок sape.ru в Rails-приложениях. 
Поддерживается вывод ссылок в формате блоков и вывод счетчика SAPE.

По мотивам https://github.com/hazg/sape-rails.
Внимание: формат файла links.db не совместим с hazg/sape-rails. 


## Установка

Добавляем в Gemfile:

    gem 'sape-rails', :git => 'git://github.com/borischernov/sape-rails'

Запускаем:

    $ bundle

## Использование
  
Добавляем config/sape.yml, в котором

```yml
user_id: xxxxxxxxxxxxxxxxxxxxxxxxxxxx         # номер в SAPE
filename: /rails_app_root/tmp/links.db        # опционально, путь до links.db
timeout: 3600								  # опционально, период обновления links.db, в секундах 
charset: UTF-8								  # опционально, кодировка
show_counter_separately: false				  # опционально, выводить счетчик отдельно от ссылок
force_show_code: false 						  # опционально, выводить код SAPE даже при отсутствии ссылок
```

В шаблоне

Ссылки в обычном формате:

```erb  
<%= return_sape_links(кол-во ссылок, опции) %>  
```
Оба параметра не обязательны.

Oпции:

:as_block - true / false, показывать ссылки в формате блока


Ссылки в формате блоков:

```erb  
<%= return_sape_block_links(кол-во ссылок, опции) %>  
```

Оба параметра не обязательны.

Oпции:

:block_orientation - 	0 - вертикальный блок, 1 - горизонтальный блок (по умолчанию)
:block_no_css 	   - 	true / false, не выводить CSS
:block_width	   -	ширина блока (параметр width в CSS)


Вывод счетчика (если в конфиге show_counter_separately: true):
```erb  
<%= return_sape_counter %>  
```



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

