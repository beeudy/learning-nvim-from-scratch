// remove_zh.js
// 复制歌词前，在浏览器地址栏或者控制台执行这行代码，能直接干掉中文
document.querySelectorAll('span[lang="zh"]').forEach(el => el.remove());
