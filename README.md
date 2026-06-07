当期目的：先做一个能处理歌词的lua插件

技术栈：lua

### 怎么使用这个歌词清理工具？

1. **第一步（在网页上）**：
   在浏览器里新建一个书签（随便起个名字，比如叫“去中文”）。
   把下面这段代码复制到这个书签的“网址”一栏里：
```javascript
   javascript:(function(){document.querySelectorAll('span[lang="zh"]').forEach(el=>el.remove())})()
