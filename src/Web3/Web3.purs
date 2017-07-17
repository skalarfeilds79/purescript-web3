module Web3.Web3 where

import Prelude
import Control.Monad.Reader.Class (class MonadAsk, ask)
import Control.Monad.Reader.Trans (ReaderT, runReaderT)
import Control.Monad.Eff (kind Effect)
import Control.Monad.Eff.Exception (EXCEPTION, throw)
import Control.Monad.Eff.Class (class MonadEff, liftEff)
import Control.Monad.Eff.Uncurried (EffFn1, EffFn2, runEffFn1, runEffFn2)
import Data.Foreign (Foreign)
import Data.Foreign.Class (class Decode, decode)
import Data.Generic.Rep (class Generic)
import Data.Generic.Rep.Show (genericShow)
import Data.Foreign.Generic (defaultOptions, genericDecode)
import Data.Either (Either(..))
import Control.Monad.Except (runExcept)

import Web3.Utils.Types (Address, HexString)
import Web3.Utils.Utils (BlockId)
import Web3.Utils.BigNumber (BigNumber)

--------------------------------------------------------------------------------
-- * Web3 Object
--------------------------------------------------------------------------------

foreign import data Web3 :: Type

foreign import newWeb3 :: forall eff . EffFn1 (eth :: ETH | eff) String Web3

--------------------------------------------------------------------------------
-- * Web3T
--------------------------------------------------------------------------------

foreign import data ETH :: Effect

data Web3T m a = Web3T (ReaderT Web3 m a)

foreign import web3ShowImpl :: Web3 -> String

instance showWeb3 :: Show Web3 where
  show = web3ShowImpl

unWeb3 :: forall m a . Web3T m a -> ReaderT Web3 m a
unWeb3 (Web3T action) = action

execWeb3 :: forall eff m a . MonadEff (eth :: ETH | eff) m
         => String
         -> Web3T m a
         -> m a
execWeb3 provider = \(Web3T action) -> do
  web3 <- liftEff $ runEffFn1 newWeb3 provider
  runReaderT action web3

-- instances

instance web3MFunctor :: Functor m => Functor (Web3T m) where
  map f (Web3T m) = Web3T (map f m)

instance web3MApply :: Apply m => Apply (Web3T m) where
  apply (Web3T f) (Web3T m) = Web3T (apply f m)

instance web3MApplicative :: Applicative m => Applicative (Web3T m) where
  pure = Web3T <<< pure

instance web3MBind :: Bind m => Bind (Web3T m) where
  bind (Web3T m) f = Web3T (m >>= (unWeb3 <<< f))

instance web3MMonad :: (Applicative m, Bind m) => Monad (Web3T m)

instance web3MEff :: MonadEff eff m => MonadEff eff (Web3T m) where
  liftEff = Web3T <<< liftEff

instance web3Reader :: Monad m => MonadAsk Web3 (Web3T m) where
  ask = Web3T ask

--------------------------------------------------------------------------------
-- * Eth
--------------------------------------------------------------------------------

data Block
  = Block { gasLimit :: Number
          , gasUsed :: Number
          , size :: Number
          , number :: Number
          , difficulty :: BigNumber
          , totalDifficulty :: BigNumber
          , transactions :: Array HexString
          }

derive instance blockGeneric :: Generic Block _

instance showBlock :: Show Block where
  show = genericShow

instance blockDecode :: Decode Block where
  decode x = genericDecode (defaultOptions { unwrapSingleConstructors = true }) x


getBalance :: forall eff m . MonadEff (eth :: ETH | eff) m => Address -> BlockId -> Web3T m BigNumber
getBalance addr bid = do
  web3 <- ask
  liftEff $ runEffFn2 (_getBalance web3) addr (show bid)

foreign import _getBalance :: forall eff . Web3 -> EffFn2 (eth :: ETH | eff) Address String BigNumber

getBlock :: forall eff m . MonadEff (eth :: ETH, exception :: EXCEPTION | eff) m => BlockId -> Web3T m Block
getBlock bid = do
  web3 <- ask
  block <- liftEff $ runEffFn1 (_getBlock web3) (show bid)
  case runExcept <<< decode $ block of
    Left e -> liftEff <<< throw <<< show $ e
    Right res -> pure res

foreign import _getBlock :: forall eff . Web3 -> EffFn1 (eth :: ETH | eff) String Foreign

isConnected :: forall eff m. MonadEff (eth :: ETH | eff) m => Web3T m Boolean
isConnected = do
  web3 <- ask
  liftEff $ runEffFn1 _isConnected web3

foreign import _isConnected :: forall eff . EffFn1 (eth :: ETH | eff) Web3 Boolean
