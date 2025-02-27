module Web3Spec.Encoding.GenericSpec (spec) where

import Prelude
import Control.Error.Util (hush)
import Data.Array (unsafeIndex, uncons)
import Data.Functor.Tagged (Tagged, tagged)
import Data.Generic.Rep (class Generic)
import Data.Eq.Generic (genericEq)
import Data.Show.Generic (genericShow)
import Data.Maybe (Maybe(..), fromJust)
import Data.Newtype (class Newtype, wrap)
import Record.Builder (build, merge)
import Type.Proxy (Proxy(..))
import Network.Ethereum.Web3.Solidity (type (:&), Address, D2, D5, D6, DOne, Tuple1, Tuple2(..), Tuple3(..), UIntN, fromData)
import Network.Ethereum.Web3.Solidity.Event (class IndexedEvent, decodeEvent, genericArrayParser)
import Network.Ethereum.Web3.Solidity.Generic (genericToRecordFields)
import Network.Ethereum.Web3.Types (Change(..), HexString, embed, mkAddress, mkHexString)
import Partial.Unsafe (unsafePartial)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import Network.Ethereum.Web3.Solidity.Sizes (S256)

spec :: Spec Unit
spec =
  describe "encoding-spec for generics" do
    toRecordFieldsSpec

toRecordFieldsSpec :: Spec Unit
toRecordFieldsSpec =
  describe "test ToRecordFields class" do
    it "pass toRecordFields basic test" do
      let
        as = Tuple3 (tagged 1) (tagged "hello") (tagged 'c') :: Tuple3 (Tagged (Proxy "a") Int) (Tagged (Proxy "d") String) (Tagged (Proxy "e") Char)
      WeirdTuple (genericToRecordFields as)
        `shouldEqual`
          WeirdTuple
            { a: 1
            , d: "hello"
            , e: 'c'
            }
    it "passes the merging test" do
      let
        as = Tuple3 (tagged 1) (tagged "hello") (tagged 'c') :: Tuple3 (Tagged (Proxy "a") Int) (Tagged (Proxy "d") String) (Tagged (Proxy "e") Char)

        as' = Tuple2 (tagged 2) (tagged "bye") :: Tuple2 (Tagged (Proxy "b") Int) (Tagged (Proxy "c") String)

        c = CombinedTuple $ build (merge (genericToRecordFields as)) (genericToRecordFields as')
      c `shouldEqual` CombinedTuple { a: 1, b: 2, c: "bye", d: "hello", e: 'c' }
    it "can parse a change an address array" do
      let
        (Transfer t) = transfer

        expected = Tuple2 (tagged t.to) (tagged t.from) :: Tuple2 (Tagged (Proxy "to") Address) (Tagged (Proxy "from") Address)
      hush (fromData (unsafePartial $ unsafeIndex addressArray 1)) `shouldEqual` Just t.to
      genericArrayParser (unsafePartial fromJust $ _.tail <$> uncons addressArray) `shouldEqual` Just expected
    it "can combine events" do
      decodeEvent change `shouldEqual` Just transfer

newtype WeirdTuple
  = WeirdTuple { a :: Int, d :: String, e :: Char }

derive instance genericWeirdTuple :: Generic WeirdTuple _

instance showWeirdTuple :: Show WeirdTuple where
  show = genericShow

instance eqWeirdTuple :: Eq WeirdTuple where
  eq = genericEq

newtype OtherTuple
  = OtherTuple { b :: Int, c :: String }

derive instance genericOtherTuple :: Generic OtherTuple _

instance showOtherTuple :: Show OtherTuple where
  show = genericShow

instance eqOtherTuple :: Eq OtherTuple where
  eq = genericEq

data CombinedTuple
  = CombinedTuple { a :: Int, b :: Int, c :: String, d :: String, e :: Char }

derive instance genericCombinedTuple :: Generic CombinedTuple _

instance showCombinedTuple :: Show CombinedTuple where
  show = genericShow

instance eqCombinedTuple :: Eq CombinedTuple where
  eq = genericEq

--------------------------------------------------------------------------------
newtype Transfer
  = Transfer { to :: Address, from :: Address, amount :: UIntN S256 }

derive instance newtypeTransfer :: Newtype Transfer _

derive instance genericTransfer :: Generic Transfer _

instance indexedTransfer :: IndexedEvent (Tuple2 (Tagged (Proxy "to") Address) (Tagged (Proxy "from") Address)) (Tuple1 (Tagged (Proxy "amount") (UIntN (D2 :& D5 :& DOne D6)))) Transfer where
  isAnonymous _ = false

instance showTransfer :: Show Transfer where
  show = genericShow

instance eqTransfer :: Eq Transfer where
  eq = genericEq

transfer :: Transfer
transfer =
  let
    t = unsafePartial fromJust $ mkAddress =<< mkHexString "0x407d73d8a49eeb85d32cf465507dd71d507100c1"

    f = unsafePartial fromJust $ mkAddress =<< mkHexString "0x0000000000000000000000000000000000000001"

    a = unsafePartial fromJust $ map hush fromData =<< mkHexString "0x0000000000000000000000000000000000000000000000000000000000000001"
  in
    Transfer
      { to: t
      , from: f
      , amount: a
      }

addressArray :: Array HexString
addressArray =
  let
    to = unsafePartial fromJust $ mkHexString "0x000000000000000000000000407d73d8a49eeb85d32cf465507dd71d507100c1"

    from = unsafePartial fromJust $ mkHexString "0x0000000000000000000000000000000000000000000000000000000000000001"

    topic = unsafePartial fromJust $ mkHexString "0x"
  in
    [ topic, to, from ]

amount :: HexString
amount = unsafePartial fromJust $ mkHexString "0x0000000000000000000000000000000000000000000000000000000000000001"

change :: Change
change =
  Change
    { data: amount
    , topics: addressArray
    , logIndex: zero
    , transactionHash: tx
    , transactionIndex: zero
    , blockNumber: wrap $ embed 0
    , blockHash: bh
    , address: a
    , removed: false
    }
  where
  bh = unsafePartial fromJust $ mkHexString "00"

  tx = unsafePartial fromJust $ mkHexString "00"

  a = unsafePartial fromJust $ mkAddress =<< mkHexString "0x0000000000000000000000000000000000000000"
