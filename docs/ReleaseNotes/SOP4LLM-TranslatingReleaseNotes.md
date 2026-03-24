# LLM 專用的對 Release Notes 的翻譯準則


- 優先檢查原始文本是否符合專案 codebase 實際描述。不符合描述的內容得斧正。
- 基礎語言為 English、zh-Hans、zh-Hant、Japanese。基礎語言的術語得與 MadTunesKit 內建的 Resources 裡面的 xcstrings 完全一致。zh-Hans 故意使用了一些台澎金馬IT術語、以求語義上的準確性，因為簡體中文資訊電子術語體系有很多用語在語義上是完全站不住腳的。
- 其他二級語言（Secondary Languages） `korean, deutsch, es, fr, it, ja, pt-BR, ru, turkey` 在翻譯時千萬不要為了文意通順而扭曲原文的術語準確性。典例：File Extension 就是 File Extension，不是 File Type。不要指鹿為馬！不要指鹿為馬！不要指鹿為馬！很重要，所以講三遍。指鹿為馬等於虛假宣傳，在 App Store 是 Unforgivable Sin，被處分了的話沒辦法抗訴的。
- 如果你發現日語翻譯缺失的話，那就是需要你就英文與中文作為原文來補全日語翻譯的時候。但這種情況並不是每次都有。此時也須注意上一條 Secondary Language 的規則。
- 在處理 Secondary Languages 時，除了需要將日語作為 Secondary Language 來處理的場合以外，在處理的時候，你或可直接推翻既有全文翻譯、重建翻譯，以節省你的算力。這一條規定對 Claude Opus 不適用。
