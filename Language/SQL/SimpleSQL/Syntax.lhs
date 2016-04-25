
> -- | The AST for SQL.
> {-# LANGUAGE DeriveDataTypeable #-}
> module Language.SQL.SimpleSQL.Syntax
>     (-- * Scalar expressions
>      ScalarExpr(..)
>     ,Name(..)
>     ,TypeName(..)
>     ,IntervalTypeField(..)
>     ,Sign(..)
>     ,PrecMultiplier(..)
>     ,PrecUnits(..)
>     ,SetQuantifier(..)
>     ,SortSpec(..)
>     ,Direction(..)
>     ,NullsOrder(..)
>     ,InPredValue(..)
>     ,SubQueryExprType(..)
>     ,CompPredQuantifier(..)
>     ,Frame(..)
>     ,FrameRows(..)
>     ,FramePos(..)
>     ,OdbcLiteralType(..)
>      -- * Query expressions
>     ,QueryExpr(..)
>     ,makeSelect
>     ,SetOperatorName(..)
>     ,Corresponding(..)
>     ,Alias(..)
>     ,GroupingExpr(..)
>      -- ** From
>     ,TableRef(..)
>     ,JoinType(..)
>     ,JoinCondition(..)
>      -- * Statements
>     ,Statement(..)
>     ,DropBehaviour(..)
>     ,IdentityRestart(..)
>     ,InsertSource(..)
>     ,SetClause(..)
>     ,TableElement(..)
>     ,ColumnDef(..)
>     ,DefaultClause(..)
>     ,IdentityWhen(..)
>     ,SequenceGeneratorOption(..)
>     ,ColConstraintDef(..)
>     ,ColConstraint(..)
>     ,TableConstraint(..)
>     ,ReferenceMatch(..)
>     ,ReferentialAction(..)
>     ,AlterTableAction(..)
>     ,CheckOption(..)
>     ,AlterDomainAction(..)
>     ,AdminOption(..)
>     ,GrantOption(..)
>     ,PrivilegeObject(..)
>     ,PrivilegeAction(..)
>     ,AdminOptionFor(..)
>     ,GrantOptionFor(..)
>      -- * Dialects
>     ,Dialect(allowOdbc)
>     ,ansi2011
>     ,mysql
>     ,postgres
>     ,oracle
>     ,sqlserver
>      -- * Comment
>     ,Comment(..)
>     ) where

> import Data.Data
> import Language.SQL.SimpleSQL.Dialect
> import GHC.Generics
> import Language.Sexp
> import Data.Sexp

> -- | Represents a value expression. This is used for the expressions
> -- in select lists. It is also used for expressions in where, group
> -- by, having, order by and so on.
> data ScalarExpr
>     = -- | a numeric literal optional decimal point, e+-
>       -- integral exponent, e.g
>       --
>       -- * 10
>       --
>       -- * 10.
>       --
>       -- * .1
>       --
>       -- * 10.1
>       --
>       -- * 1e5
>       --
>       -- * 12.34e-6
>       NumLit String
>       -- | string literal, with the start and end quote
>       -- e.g. 'test' -> StringLit "'" "'" "test"
>     | StringLit String String String
>       -- | text of interval literal, units of interval precision,
>       -- e.g. interval 3 days (3)
>     | IntervalLit
>       {ilSign :: Maybe Sign -- ^ if + or - used
>       ,ilLiteral :: String -- ^ literal text
>       ,ilFrom :: IntervalTypeField
>       ,ilTo :: Maybe IntervalTypeField
>       }

>       -- | prefix 'typed literal', e.g. int '42'
>     | TypedLit TypeName String

>       -- | identifier with parts separated by dots
>     | Iden [Name]
>       -- | star, as in select *, t.*, count(*)
>     | Star

>     | Parameter -- ^ Represents a ? in a parameterized query
>     | PositionalArg Int -- ^ Represents an e.g. $1 in a parameterized query
>     | HostParameter String (Maybe String) -- ^ represents a host
>                                           -- parameter, e.g. :a. The
>                                           -- Maybe String is for the
>                                           -- indicator, e.g. :var
>                                           -- indicator :nl


>       -- | Infix binary operators. This is used for symbol operators
>       -- (a + b), keyword operators (a and b) and multiple keyword
>       -- operators (a is similar to b)
>     | BinOp ScalarExpr [Name] ScalarExpr
>       -- | Prefix unary operators. This is used for symbol
>       -- operators, keyword operators and multiple keyword operators.
>     | PrefixOp [Name] ScalarExpr
>       -- | Postfix unary operators. This is used for symbol
>       -- operators, keyword operators and multiple keyword operators.
>     | PostfixOp [Name] ScalarExpr
>       -- | Used for ternary, mixfix and other non orthodox
>       -- operators. Currently used for row constructors, and for
>       -- between.
>     | SpecialOp [Name] [ScalarExpr]

>       -- | function application (anything that looks like c style
>       -- function application syntactically)
>     | App [Name] [ScalarExpr]


>       -- | aggregate application, which adds distinct or all, and
>       -- order by, to regular function application
>     | AggregateApp
>       {aggName :: [Name] -- ^ aggregate function name
>       ,aggDistinct :: SetQuantifier -- ^ distinct
>       ,aggArgs :: [ScalarExpr]-- ^ args
>       ,aggOrderBy :: [SortSpec] -- ^ order by
>       ,aggFilter :: Maybe ScalarExpr -- ^ filter
>       }
>       -- | aggregates with within group
>     | AggregateAppGroup
>       {aggName :: [Name] -- ^ aggregate function name
>       ,aggArgs :: [ScalarExpr] -- ^ args
>       ,aggGroup :: [SortSpec] -- ^ within group
>       }
>       -- | window application, which adds over (partition by a order
>       -- by b) to regular function application. Explicit frames are
>       -- not currently supported
>     | WindowApp
>       {wnName :: [Name] -- ^ window function name
>       ,wnArgs :: [ScalarExpr] -- ^ args
>       ,wnPartition :: [ScalarExpr] -- ^ partition by
>       ,wnOrderBy :: [SortSpec] -- ^ order by
>       ,wnFrame :: Maybe Frame -- ^ frame clause
>       }

>       -- | Used for the operators which look like functions
>       -- except the arguments are separated by keywords instead
>       -- of commas. The maybe is for the first unnamed argument
>       -- if it is present, and the list is for the keyword argument
>       -- pairs.
>     | SpecialOpK [Name] (Maybe ScalarExpr) [(String,ScalarExpr)]

>       -- | cast(a as typename)
>     | Cast ScalarExpr TypeName

>       -- | case expression. both flavours supported
>     | Case
>       {caseTest :: Maybe ScalarExpr -- ^ test value
>       ,caseWhens :: [([ScalarExpr],ScalarExpr)] -- ^ when branches
>       ,caseElse :: Maybe ScalarExpr -- ^ else value
>       }

>     | Parens ScalarExpr

>       -- | in list literal and in subquery, if the bool is false it
>       -- means not in was used ('a not in (1,2)')
>     | In Bool ScalarExpr InPredValue

>       -- | exists, all, any, some subqueries
>     | SubQueryExpr SubQueryExprType QueryExpr

>     | QuantifiedComparison
>             ScalarExpr
>             [Name] -- operator
>             CompPredQuantifier
>             QueryExpr

>     | Match ScalarExpr Bool -- true if unique
>           QueryExpr
>     | Array ScalarExpr [ScalarExpr] -- ^ represents an array
>                                   -- access expression, or an array ctor
>                                   -- e.g. a[3]. The first
>                                   -- scalarExpr is the array, the
>                                   -- second is the subscripts/ctor args
>     | ArrayCtor QueryExpr -- ^ this is used for the query expression version of array constructors, e.g. array(select * from t)

todo: special syntax for like, similar with escape - escape cannot go
in other places

>     --  | Escape ScalarExpr Char
>     --  | UEscape ScalarExpr Char
>     | Collate ScalarExpr [Name]
>     | MultisetBinOp ScalarExpr SetOperatorName SetQuantifier ScalarExpr
>     | MultisetCtor [ScalarExpr]
>     | MultisetQueryCtor QueryExpr
>     | NextValueFor [Name]
>     | VEComment [Comment] ScalarExpr
>     | OdbcLiteral OdbcLiteralType String
>       -- ^ an odbc literal e.g. {d '2000-01-01'}
>     | OdbcFunc ScalarExpr
>       -- ^ an odbc function call e.g. {fn CHARACTER_LENGTH('test')}
>       deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents an identifier name, which can be quoted or unquoted.
> -- examples:
> --
> -- * test -> Name Nothing "test"
> -- * "test" -> Name (Just "\"","\"") "test"
> -- * `something` -> Name (Just ("`","`") "something"
> -- * [ms] -> Name (Just ("[","]") "ms"
> data Name = Name (Maybe (String,String)) String
>             deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents a type name, used in casts.
> data TypeName
>     = TypeName [Name]
>     | PrecTypeName [Name] Integer
>     | PrecScaleTypeName [Name] Integer Integer
>     | PrecLengthTypeName [Name] Integer (Maybe PrecMultiplier) (Maybe PrecUnits)
>       -- precision, characterset, collate
>     | CharTypeName [Name] (Maybe Integer) [Name] [Name]
>     | TimeTypeName [Name] (Maybe Integer) Bool -- true == with time zone
>     | RowTypeName [(Name,TypeName)]
>     | IntervalTypeName IntervalTypeField (Maybe IntervalTypeField)
>     | ArrayTypeName TypeName (Maybe Integer)
>     | MultisetTypeName TypeName
>       deriving (Eq,Show,Read,Data,Typeable,Generic)

> data IntervalTypeField = Itf String (Maybe (Integer, Maybe Integer))
>                          deriving (Eq,Show,Read,Data,Typeable,Generic)

> data Sign = Plus | Minus
>             deriving (Eq,Show,Read,Data,Typeable,Generic)

> data PrecMultiplier = PrecK | PrecM | PrecG | PrecT | PrecP
>                       deriving (Eq,Show,Read,Data,Typeable,Generic)
> data PrecUnits = PrecCharacters
>                | PrecOctets
>                 deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Used for 'expr in (scalar expression list)', and 'expr in
> -- (subquery)' syntax.
> data InPredValue = InList [ScalarExpr]
>                  | InQueryExpr QueryExpr
>                    deriving (Eq,Show,Read,Data,Typeable,Generic)

not sure if scalar subquery, exists and unique should be represented like this

> -- | A subquery in a scalar expression.
> data SubQueryExprType
>     = -- | exists (query expr)
>       SqExists
>       -- | unique (query expr)
>     | SqUnique
>       -- | a scalar subquery
>     | SqSq
>       deriving (Eq,Show,Read,Data,Typeable,Generic)

> data CompPredQuantifier
>     = CPAny
>     | CPSome
>     | CPAll
>       deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents one field in an order by list.
> data SortSpec = SortSpec ScalarExpr Direction NullsOrder
>                 deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents 'nulls first' or 'nulls last' in an order by clause.
> data NullsOrder = NullsOrderDefault
>                 | NullsFirst
>                 | NullsLast
>                   deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents the frame clause of a window
> -- this can be [range | rows] frame_start
> -- or [range | rows] between frame_start and frame_end
> data Frame = FrameFrom FrameRows FramePos
>            | FrameBetween FrameRows FramePos FramePos
>              deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents whether a window frame clause is over rows or ranges.
> data FrameRows = FrameRows | FrameRange
>                  deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | represents the start or end of a frame
> data FramePos = UnboundedPreceding
>               | Preceding ScalarExpr
>               | Current
>               | Following ScalarExpr
>               | UnboundedFollowing
>                 deriving (Eq,Show,Read,Data,Typeable,Generic)


> -- | the type of an odbc literal (e.g. {d '2000-01-01'}),
> -- correpsonding to the letter after the opening {
> data OdbcLiteralType = OLDate
>                      | OLTime
>                      | OLTimestamp
>                        deriving (Eq,Show,Read,Data,Typeable,Generic)


> -- | Represents a query expression, which can be:
> --
> -- * a regular select;
> --
> -- * a set operator (union, except, intersect);
> --
> -- * a common table expression (with);
> --
> -- * a table value constructor (values (1,2),(3,4)); or
> --
> -- * an explicit table (table t).
> data QueryExpr
>     = Select
>       {qeSetQuantifier :: SetQuantifier
>       ,qeSelectList :: [(ScalarExpr,Maybe Name)]
>        -- ^ the expressions and the column aliases

TODO: consider breaking this up. The SQL grammar has
queryexpr = select <select list> [<table expression>]
table expression = <from> [where] [groupby] [having] ...

This would make some things a bit cleaner?

>       ,qeFrom :: [TableRef]
>       ,qeWhere :: Maybe ScalarExpr
>       ,qeGroupBy :: [GroupingExpr]
>       ,qeHaving :: Maybe ScalarExpr
>       ,qeOrderBy :: [SortSpec]
>       ,qeOffset :: Maybe ScalarExpr
>       ,qeFetchFirst :: Maybe ScalarExpr
>       }
>     | QueryExprSetOp
>       {qe0 :: QueryExpr
>       ,qeCombOp :: SetOperatorName
>       ,qeSetQuantifier :: SetQuantifier
>       ,qeCorresponding :: Corresponding
>       ,qe1 :: QueryExpr
>       }
>     | With
>       {qeWithRecursive :: Bool
>       ,qeViews :: [(Alias,QueryExpr)]
>       ,qeQueryExpression :: QueryExpr}
>     | Values [[ScalarExpr]]
>     | Table [Name]
>     | QEComment [Comment] QueryExpr
>       deriving (Eq,Show,Read,Data,Typeable, Generic)

TODO: add queryexpr parens to deal with e.g.
(select 1 union select 2) union select 3
I'm not sure if this is valid syntax or not.

> -- | Helper/'default' value for query exprs to make creating query
> -- expr values a little easier. It is defined like this:
> --
> -- > makeSelect :: QueryExpr
> -- > makeSelect = Select {qeSetQuantifier = SQDefault
> -- >                     ,qeSelectList = []
> -- >                     ,qeFrom = []
> -- >                     ,qeWhere = Nothing
> -- >                     ,qeGroupBy = []
> -- >                     ,qeHaving = Nothing
> -- >                     ,qeOrderBy = []
> -- >                     ,qeOffset = Nothing
> -- >                     ,qeFetchFirst = Nothing}

> makeSelect :: QueryExpr
> makeSelect = Select {qeSetQuantifier = SQDefault
>                     ,qeSelectList = []
>                     ,qeFrom = []
>                     ,qeWhere = Nothing
>                     ,qeGroupBy = []
>                     ,qeHaving = Nothing
>                     ,qeOrderBy = []
>                     ,qeOffset = Nothing
>                     ,qeFetchFirst = Nothing}

> -- | Represents the Distinct or All keywords, which can be used
> -- before a select list, in an aggregate/window function
> -- application, or in a query expression set operator.
> data SetQuantifier = SQDefault | Distinct | All deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | The direction for a column in order by.
> data Direction = DirDefault | Asc | Desc deriving (Eq,Show,Read,Data,Typeable,Generic)
> -- | Query expression set operators.
> data SetOperatorName = Union | Except | Intersect deriving (Eq,Show,Read,Data,Typeable,Generic)
> -- | Corresponding, an option for the set operators.
> data Corresponding = Corresponding | Respectively deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents an item in a group by clause.
> data GroupingExpr
>     = GroupingParens [GroupingExpr]
>     | Cube [GroupingExpr]
>     | Rollup [GroupingExpr]
>     | GroupingSets [GroupingExpr]
>     | SimpleGroup ScalarExpr
>       deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents a entry in the csv of tables in the from clause.
> data TableRef = -- | from t / from s.t
>                 TRSimple [Name]
>                 -- | from a join b, the bool is true if natural was used
>               | TRJoin TableRef Bool JoinType TableRef (Maybe JoinCondition)
>                 -- | from (a)
>               | TRParens TableRef
>                 -- | from a as b(c,d)
>               | TRAlias TableRef Alias
>                 -- | from (query expr)
>               | TRQueryExpr QueryExpr
>                 -- | from function(args)
>               | TRFunction [Name] [ScalarExpr]
>                 -- | from lateral t
>               | TRLateral TableRef
>                 -- | ODBC {oj t1 left outer join t2 on expr} syntax
>               | TROdbc TableRef
>                 deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Represents an alias for a table valued expression, used in with
> -- queries and in from alias, e.g. select a from t u, select a from t u(b),
> -- with a(c) as select 1, select * from a.
> data Alias = Alias Name (Maybe [Name])
>              deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | The type of a join.
> data JoinType = JInner | JLeft | JRight | JFull | JCross
>                 deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | The join condition.
> data JoinCondition = JoinOn ScalarExpr -- ^ on expr
>                    | JoinUsing [Name] -- ^ using (column list)
>                      deriving (Eq,Show,Read,Data,Typeable,Generic)

---------------------------

> data Statement =
>     -- ddl
>     CreateSchema [Name]
>   | DropSchema [Name] DropBehaviour
>   | CreateTable [Name] [TableElement]
>   | AlterTable [Name] AlterTableAction
>   | DropTable [Name] DropBehaviour
>   | CreateView Bool [Name] (Maybe [Name])
>         QueryExpr (Maybe CheckOption)
>   | DropView [Name]  DropBehaviour
>   | CreateDomain [Name] TypeName (Maybe ScalarExpr)
>        [(Maybe [Name], ScalarExpr)]
>   | AlterDomain [Name] AlterDomainAction
>   | DropDomain [Name] DropBehaviour

>     -- probably won't do character sets, collations
>     -- and translations because I think they are too far from
>     -- reality
>   {-  | CreateCharacterSet
>   | DropCharacterSet
>   | CreateCollation
>   | DropCollation
>   | CreateTranslation
>   | DropTranslation -}
>   | CreateAssertion [Name] ScalarExpr
>   | DropAssertion [Name] DropBehaviour
>   {-   | CreateTrigger
>   | DropTrigger
>   | CreateType
>   | AlterType
>   | DropType
>     -- routine stuff? TODO
>   | CreateCast
>   | DropCast
>   | CreateOrdering
>   | DropOrdering -}
>     -- transforms
>   | CreateSequence [Name] [SequenceGeneratorOption]
>   | AlterSequence [Name] [SequenceGeneratorOption]
>   | DropSequence [Name] DropBehaviour
>     -- dml
>   | SelectStatement QueryExpr
>   {-    | DeclareCursor
>   | OpenCursor
>   | FetchCursor
>   | CloseCursor
>   | SelectInto -}
>   --   | DeletePositioned
>   | Delete [Name] (Maybe Name) (Maybe ScalarExpr)
>   | Truncate [Name] IdentityRestart
>   | Insert [Name] (Maybe [Name]) InsertSource
>   --  | Merge
>   | Update [Name] (Maybe Name) [SetClause] (Maybe ScalarExpr)
>   {-  | TemporaryTable
>   | FreeLocator
>   | HoldLocator  -}
>     -- access control
>   | GrantPrivilege [PrivilegeAction] PrivilegeObject [Name] GrantOption
>   | GrantRole [Name] [Name] AdminOption
>   | CreateRole Name
>   | DropRole Name
>   | RevokePrivilege GrantOptionFor [PrivilegeAction] PrivilegeObject
>             [Name] DropBehaviour
>   | RevokeRole AdminOptionFor [Name] [Name] DropBehaviour
>     -- transaction management
>   | StartTransaction
>   --  | SetTransaction
>   --  | SetContraints
>   | Savepoint Name
>   | ReleaseSavepoint Name
>   | Commit
>   | Rollback (Maybe Name)
>     -- session
>   {-  | SetSessionCharacteristics
>   | SetSessionAuthorization
>   | SetRole
>   | SetTimeZone
>   | SetCatalog
>   | SetSchema
>   | SetNames
>   | SetTransform
>   | SetCollation -}
>   | StatementComment [Comment]
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data DropBehaviour =
>     Restrict
>   | Cascade
>   | DefaultDropBehaviour
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data IdentityRestart =
>     ContinueIdentity
>   | RestartIdentity
>   | DefaultIdentityRestart
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data InsertSource =
>     InsertQuery QueryExpr
>   | DefaultInsertValues
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data SetClause =
>     Set [Name] ScalarExpr
>   | SetMultiple [[Name]] [ScalarExpr]
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data TableElement =
>     TableColumnDef ColumnDef
>   | TableConstraintDef (Maybe [Name]) TableConstraint
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ColumnDef = ColumnDef Name TypeName
>        (Maybe DefaultClause)
>        [ColConstraintDef]
>        -- (Maybe CollateClause)
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ColConstraintDef =
>     ColConstraintDef (Maybe [Name]) ColConstraint
>       -- (Maybe [ConstraintCharacteristics])
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ColConstraint =
>     ColNotNullConstraint
>   | ColUniqueConstraint
>   | ColPrimaryKeyConstraint
>   | ColReferencesConstraint [Name] (Maybe Name)
>        ReferenceMatch
>        ReferentialAction
>        ReferentialAction
>   | ColCheckConstraint ScalarExpr
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data TableConstraint =
>     TableUniqueConstraint [Name]
>   | TablePrimaryKeyConstraint [Name]
>   | TableReferencesConstraint [Name] [Name] (Maybe [Name])
>        ReferenceMatch
>        ReferentialAction
>        ReferentialAction
>   | TableCheckConstraint ScalarExpr
>     deriving (Eq,Show,Read,Data,Typeable,Generic)


> data ReferenceMatch =
>     DefaultReferenceMatch
>   | MatchFull
>   | MatchPartial
>   | MatchSimple
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ReferentialAction =
>     DefaultReferentialAction
>   | RefCascade
>   | RefSetNull
>   | RefSetDefault
>   | RefRestrict
>   | RefNoAction
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data AlterTableAction =
>     AddColumnDef ColumnDef
>   | AlterColumnSetDefault Name ScalarExpr
>   | AlterColumnDropDefault Name
>   | AlterColumnSetNotNull Name
>   | AlterColumnDropNotNull Name
>   | AlterColumnSetDataType Name TypeName
>   {-  | AlterColumnAlterIdentity
>   | AlterColumnDropIdentity
>   | AlterColumnDropColumnGeneration-}
>   | DropColumn Name DropBehaviour
>   | AddTableConstraintDef (Maybe [Name]) TableConstraint
>   --  | AlterTableConstraintDef
>   | DropTableConstraintDef [Name] DropBehaviour
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> {-data ConstraintCharacteristics =
>     ConstraintCharacteristics
>         ConstraintCheckTime
>         Deferrable
>         ConstraintEnforcement
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ConstraintCheckTime =
>     DefaultConstraintCheckTime
>   | InitiallyDeferred
>   | InitiallyImmeditate
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data Deferrable =
>     DefaultDefferable
>   | Deferrable
>   | NotDeferrable
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data ConstraintEnforcement =
>     DefaultConstraintEnforcement
>   | Enforced
>   | NotEnforced
>     deriving (Eq,Show,Read,Data,Typeable,Generic) -}

> {-data TableConstraintDef
>     deriving (Eq,Show,Read,Data,Typeable,Generic) -}

> data DefaultClause =
>      DefaultClause ScalarExpr
>    | IdentityColumnSpec IdentityWhen [SequenceGeneratorOption]
>    | GenerationClause ScalarExpr
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data IdentityWhen =
>     GeneratedAlways
>   | GeneratedByDefault
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data SequenceGeneratorOption =
>     SGODataType TypeName
>   | SGOStartWith Integer
>   | SGORestart (Maybe Integer)
>   | SGOIncrementBy Integer
>   | SGOMaxValue Integer
>   | SGONoMaxValue
>   | SGOMinValue Integer
>   | SGONoMinValue
>   | SGOCycle
>   | SGONoCycle
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data CheckOption =
>     DefaultCheckOption
>   | CascadedCheckOption
>   | LocalCheckOption
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data AlterDomainAction =
>     ADSetDefault ScalarExpr
>   | ADDropDefault
>   | ADAddConstraint (Maybe [Name]) ScalarExpr
>   | ADDropConstraint [Name]
>     deriving (Eq,Show,Read,Data,Typeable,Generic)


> data AdminOption = WithAdminOption | WithoutAdminOption
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data GrantOption = WithGrantOption | WithoutGrantOption
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data AdminOptionFor = AdminOptionFor | NoAdminOptionFor
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data GrantOptionFor = GrantOptionFor | NoGrantOptionFor
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> data PrivilegeObject =
>       PrivTable [Name]
>     | PrivDomain [Name]
>     | PrivType [Name]
>     | PrivSequence [Name]
>     | PrivFunction [Name]
>     deriving (Eq,Show,Read,Data,Typeable, Generic)

> data PrivilegeAction =
>       PrivAll
>     | PrivSelect [Name]
>     | PrivDelete
>     | PrivInsert [Name]
>     | PrivUpdate [Name]
>     | PrivReferences [Name]
>     | PrivUsage
>     | PrivTrigger
>     | PrivExecute
>     deriving (Eq,Show,Read,Data,Typeable,Generic)

> -- | Comment. Useful when generating SQL code programmatically. The
> -- parser doesn't produce these.
> data Comment = BlockComment String
>                deriving (Eq,Show,Read,Data,Typeable,Generic)

> instance Sexpable Name
> instance Sexpable IntervalTypeField
> instance Sexpable Sign
> instance Sexpable PrecMultiplier
> instance Sexpable PrecUnits
> instance Sexpable InPredValue
> instance Sexpable SortSpec
> instance Sexpable NullsOrder
> instance Sexpable Frame
> instance Sexpable FrameRows
> instance Sexpable FramePos
> instance Sexpable OdbcLiteralType
> instance Sexpable SetQuantifier
> instance Sexpable Direction
> instance Sexpable SetOperatorName
> instance Sexpable Corresponding
> instance Sexpable TableRef
> instance Sexpable Alias
> instance Sexpable JoinType
> instance Sexpable JoinCondition
> instance Sexpable Statement
> instance Sexpable DropBehaviour
> instance Sexpable IdentityRestart
> instance Sexpable InsertSource
> instance Sexpable SetClause
> instance Sexpable TableElement
> instance Sexpable ColumnDef
> instance Sexpable ColConstraintDef
> instance Sexpable ColConstraint
> instance Sexpable TableConstraint
> instance Sexpable ReferenceMatch
> instance Sexpable ReferentialAction
> instance Sexpable AlterTableAction
> instance Sexpable DefaultClause
> instance Sexpable IdentityWhen
> instance Sexpable SequenceGeneratorOption
> instance Sexpable CheckOption
> instance Sexpable AlterDomainAction
> instance Sexpable AdminOption
> instance Sexpable GrantOption
> instance Sexpable AdminOptionFor
> instance Sexpable GrantOptionFor
> instance Sexpable PrivilegeObject
> instance Sexpable PrivilegeAction
> instance Sexpable Comment
> instance Sexpable ScalarExpr
> instance Sexpable CompPredQuantifier
> instance Sexpable QueryExpr
> instance Sexpable GroupingExpr
> instance Sexpable SubQueryExprType
> instance Sexpable TypeName
