{-# LANGUAGE OverloadedStrings #-}
module Network.BitcoinRPC.Types
    ( BitcoinAmount(..)
    , BitcoinAddress(..)
    , TransactionID(..)
    , RPCAuth(..)
    , Transaction(..)
    , TransactionHeader(..)
    , TransactionOrigins(..)
    , RPCResult(..)
    )
    where

import Control.Applicative
import Control.Monad
import Data.Aeson
import Data.Aeson.Types

import qualified Data.HashMap.Strict as H
import qualified Data.Text as T

newtype BitcoinAmount = BitcoinAmount { btcAmount :: Integer }
                        deriving (Eq,Show,Read)

newtype BitcoinAddress = BitcoinAddress { btcAddress :: T.Text }
                         deriving (Eq,Show,Read)

newtype TransactionID = TransactionID { btcTxID :: T.Text }
                        deriving (Eq,Show,Read)

data RPCAuth = RPCAuth { rpcUrl :: String
                       , rpcUser :: String
                       , rpcPassword :: String
                       }
                       deriving (Show)

data Transaction = ReceiveTx { tEntry :: Integer
                             , tAmount :: BitcoinAmount
                             , tAddress :: BitcoinAddress
                             , tConfirmations :: Integer
                             , tTxid :: TransactionID
                             , tTime :: Integer
                             }
                 | SendTx { tEntry :: Integer
                          , tAmount :: BitcoinAmount
                          , tAddress :: BitcoinAddress
                          , tFee :: BitcoinAmount
                          , tConfirmations :: Integer
                          , tTxid :: TransactionID
                          , tTime :: Integer
                          }
                 | MoveTx { tTime :: Integer }
                 | GenerateTx { tEntry :: Integer
                              , tAmount :: BitcoinAmount
                              , tConfirmations :: Integer
                              , tTxid :: TransactionID
                              , tTime :: Integer
                              }
                 deriving (Eq,Show,Read)


data TransactionHeader = TransactionHeader { thAmount :: BitcoinAmount
                                           , thConfirmations :: Integer
                                           , thTxid :: TransactionID
                                           , thTime :: Integer
                                           }
                         deriving (Show)

data TransactionOrigins = TransactionOrigins { toConfirmations :: Integer
                                             , toTxid :: TransactionID
                                             , toTime :: Integer
                                             , toOrigins :: [BitcoinAddress]
                                             }
                          deriving (Show)

--data BlockCount = BlockCount { bcCount :: Integer }
--                  deriving (Show)

data RPCResult = RPCSuccess Value
               | RPCError { rpcErrorCode :: Integer
                          , rpcErrorMessage :: T.Text
                          }
               deriving (Show)

instance Num BitcoinAmount
  where
    (+) (BitcoinAmount x) (BitcoinAmount y) = BitcoinAmount (x + y)
    (*) (BitcoinAmount x) (BitcoinAmount y) = error "not supported"
    (-) (BitcoinAmount x) (BitcoinAmount y) = BitcoinAmount (x - y)
    abs (BitcoinAmount x) = BitcoinAmount (abs x)
    signum (BitcoinAmount x) = BitcoinAmount (signum x)
    fromInteger x = BitcoinAmount (fromInteger x)

instance FromJSON BitcoinAmount
  where
    parseJSON v = do
        amount <- parseJSON v :: Parser Double
        let inSatoshis = round $ amount * 10^8
        return $ BitcoinAmount inSatoshis

instance FromJSON BitcoinAddress
  where
    parseJSON (String addr) = return $ BitcoinAddress addr
    parseJSON _ = mzero

instance FromJSON TransactionID
  where
    parseJSON (String txid) = return $ TransactionID txid
    parseJSON _ = mzero

instance FromJSON Transaction
  where
    parseJSON (Object o) = case H.lookup "category" o of
        Just "send" -> SendTx <$>
                            o .: "entry" <*>
                            (abs <$> o .: "amount") <*>
                            o .: "address" <*>
                            o .: "fee" <*>
                            o .: "confirmations" <*>
                            o .: "txid" <*>
                            o .: "time"
        Just "receive" -> ReceiveTx <$>
                            o .: "entry" <*>
                            o .: "amount" <*>
                            o .: "address" <*>
                            o .: "confirmations" <*>
                            o .: "txid" <*>
                            o .: "time"
        Just "move" -> MoveTx <$>
                            o .: "time"
        Just "generate" -> GenerateTx <$>
                            o .: "entry" <*>
                            o .: "amount" <*>
                            o .: "confirmations" <*>
                            o .: "txid" <*>
                            o .: "time"
        Just _ -> mzero
        Nothing -> mzero
    parseJSON _ = mzero

instance FromJSON TransactionHeader
  where
    parseJSON (Object o) = TransactionHeader <$>
                            o .: "amount" <*>
                            o .: "confirmations" <*>
                            o .: "txid" <*>
                            o .: "time"
    parseJSON _ = mzero

instance FromJSON TransactionOrigins
  where
    parseJSON (Object o) = TransactionOrigins <$>
                            o .: "confirmations" <*>
                            o .: "txid" <*>
                            o .: "time" <*>
                            o .: "origins"
    parseJSON _ = mzero

--instance FromJSON BlockCount
--  where
--    parseJSON v@(Number _) = BlockCount <$> parseJSON v
--    parseJSON _ = mzero

instance FromJSON RPCResult
  where
    parseJSON (Object o) = case H.lookup "result" o of
        Just Null -> case H.lookup "error" o of
            Just (Object errInfo) -> RPCError <$> errInfo .: "code"
                                              <*> errInfo .: "message"
            Just Null -> mzero
            _ -> mzero
        Just result -> return $ RPCSuccess result
        _ -> mzero
    parseJSON _ = mzero