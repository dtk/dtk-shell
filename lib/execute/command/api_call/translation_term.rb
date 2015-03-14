class DTK::Client::Execute
  class Command::APICall
    class TranslationTerm
      def self.matches?(obj)
        obj.kind_of?(Class) and obj <= self
      end
    end
    class Equal < TranslationTerm
      class Required < self
      end
    end
    class Rest < TranslationTerm
      class Post < self
      end
    end
  end
end
