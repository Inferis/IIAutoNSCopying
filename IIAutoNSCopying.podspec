Pod::Spec.new do |s|
  s.name      = 'IIAutoNSCopying'
  s.platform  = :ios, 6.0
  s.version   = '0.4'
  s.summary   = 'A way to add propertybased automatic NSCopying to any object.'
  s.homepage  = "https://github.com/Inferis/#{s.name}"
  s.license   = { :type => 'MIT', :file => 'LICENSE' }
  s.social_media_url = 'https://twitter.com/inferis'
  s.author    = { 'Tom Adriaenssen' =>  'http://inferis.org/' }
  s.source    = { :git => "https://github.com/Inferis/#{s.name}.git",
                  :tag => s.version }
  s.source_files  = "#{s.name}/*.{h,m}"
  s.requires_arc  = true
end
