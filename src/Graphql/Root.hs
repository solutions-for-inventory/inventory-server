{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE DeriveAnyClass        #-}
{-# LANGUAGE QuasiQuotes           #-}
{-# LANGUAGE DuplicateRecordFields #-}


module Graphql.Root (api, apiDoc) where

import qualified Data.ByteString.Lazy.Char8 as B
import           GHC.Generics
import           Control.Monad.Except       (ExceptT (..))
import           Data.Morpheus              (interpreter)
import           Data.Morpheus.Document     (importGQLDocumentWithNamespace)
import           Data.Morpheus.Types        (GQLRootResolver (..), IORes, GQLType(..), Undefined(..), liftEither, lift, Res, MutRes, GQLRequest, GQLResponse)
import           Data.Morpheus.Kind     (OBJECT)
import           Data.Morpheus.Document (toGraphQLDocument)
import           Data.Text                  (Text)
import           Data.ByteString
import           Graphql.Deity  (Deity (..), dbDeity, fetchDeity, NoDeity(..), TestArg(..))
import           Database.Persist.Sql (toSqlKey, fromSqlKey)
import           Import
import           Graphql.Session
import           Graphql.Privilege
import           Graphql.Role
import           Graphql.Person
import           Graphql.Asset.Category
import           Graphql.Asset.Unit
import           Graphql.Maintenance.SubTask.SubTaskKind
import           Graphql.Maintenance.Task.TaskCategory
import           Graphql.Asset.Item.Resolvers
import           Graphql.Asset.Inventory.Resolvers
import           Graphql.Maintenance.Resolvers
import           Graphql.Maintenance.DataTypes
import           Graphql.Asset.Equipment.Resolvers
import           Graphql.Asset.Equipment.DataTypes
import           Graphql.Asset.InventoryItem.Resolvers
import           Graphql.Utils (PageArg)
import           Graphql.Asset.DataTypes
-- importGQLDocumentWithNamespace "schema.gql"

data QueryQL m = QueryQL { -- deity :: DeityArgs -> m Deity
                           session :: () -> Res () Handler Session
                         , privileges :: () -> m Privileges
                         , roles :: () -> m Roles
                         , persons :: () -> m Persons
                         , users :: () -> m Users
                         , categories :: () -> m [Category]
                         , units :: () -> m [Unit]
                         , taskCategories :: () -> m [TaskCategory]
                         , subTaskKinds :: () -> m [SubTaskKind]
                         , inventories :: () -> Res () Handler (Inventories Res)
                         , items :: () -> Res () Handler (Items Res)
                         , equipments :: () -> Res () Handler (Equipments Res)
                         , inventoryItems :: () -> Res () Handler (InventoryItems Res)
                         , maintenances :: () -> Res () Handler (Maintenances Res)
                         } deriving (Generic, GQLType)

data Mutation m = Mutation { savePrivilege :: PrivilegeArg -> m Privilege
                           , saveRole :: RoleArg -> m (Role MutRes)
                           , savePerson :: PersonArg -> m (Person MutRes)
                           , saveCategory :: CategoryArg -> m Category
                           , saveUnit :: UnitArg -> m Unit
                           , saveTaskCategory :: TaskCategoryArg -> m TaskCategory
                           , saveSubTaskKind :: SubTaskKindArg -> m SubTaskKind
--                           , saveInventory :: InventoryArg -> m (Inventory MutRes)
--                           , saveItem :: ItemArg -> m (Item MutRes)
--                           , saveInventoryItem :: InventoryItemArg -> m (InventoryItem MutRes)
                           , inventoryItems :: () -> MutRes () Handler (InventoryItems MutRes)
                           , items :: () -> MutRes () Handler (Items MutRes)
                           , equipments :: () -> MutRes () Handler (Equipments MutRes)
                           , inventories :: () -> MutRes () Handler (Inventories MutRes)
                           , maintenances :: () -> MutRes () Handler (Maintenances MutRes)
                           } deriving (Generic, GQLType)

--data DeityArgs = DeityArgs { name :: Text, mythology :: Maybe Text } deriving (Generic)

-- | The query resolver
resolveQuery::QueryQL (Res () Handler)
resolveQuery = QueryQL { --deity = resolveDeity
                         session = getUserSessionResolver
                       , privileges = resolvePrivilege
                       , roles = resolveRole
                       , persons = resolvePerson
                       , users = resolveUser
                       , categories = listCategoryResolver
                       , units = listUnitResolver
                       , taskCategories = listTaskCategoryResolver
                       , subTaskKinds = listSubTaskKindResolver
                       , inventories = inventoryResolver
                       , maintenances = maintenanceResolver
                       , items = itemResolver
                       , equipments = equipmentResolver
                       , inventoryItems = inventoryItemsResolver
                       }
-- | The mutation resolver
resolveMutation::Mutation (MutRes () Handler)
resolveMutation = Mutation { savePrivilege = resolveSavePrivilege
                           , saveRole =  resolveSaveRole
                           , savePerson = resolveSavePerson
                           , saveCategory = saveCategoryResolver
                           , saveUnit = saveUnitResolver
                           , saveTaskCategory = saveTaskCategoryResolver
                           , saveSubTaskKind = saveSubTaskKindResolver
--                           , saveInventory = saveInventoryResolver
--                           , saveItem =  saveItemResolver
--                           , saveInventoryItem =  saveInventoryItemResolver
                           , inventories = inventoryResolver
                           , maintenances = maintenanceResolver
                           , items = itemResolver
                           , equipments = equipmentResolver
                           , inventoryItems = inventoryItemsResolver
                           }


-- BASE EXAMPLE
-- https://github.com/dnulnets/haccessability
--dbFetchDeity:: Text -> Handler Deity
--dbFetchDeity name = do
--                     let userId = (toSqlKey 3)::User_Id
--                     deity <- runDB $ getEntity userId
--                     return $ Deity {fullName = "dummy", power = Just "Shapeshifting", tests = testsResolver}

--resolveDeity :: DeityArgs -> Res e Handler Deity
--resolveDeity DeityArgs { name, mythology } = lift $ dbFetchDeity name

--testsResolver :: TestArg -> Res e Handler NoDeity
--testsResolver TestArg {yourFullName } = pure NoDeity {noFullName = "Test no full am", nopower = Just "no power"}

rootResolver :: GQLRootResolver Handler () QueryQL Mutation Undefined
rootResolver = GQLRootResolver { queryResolver = resolveQuery
                               , mutationResolver = resolveMutation
                               , subscriptionResolver = Undefined
                               }

-- | Compose the graphQL api
api:: GQLRequest -> Handler GQLResponse
api r = do
         interpreter rootResolver r

apiDoc = toGraphQLDocument $ Just rootResolver
